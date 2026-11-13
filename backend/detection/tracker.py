"""
BirdTracker — IoU + velocity re-identification tracker.

Three-stage matching:
  Stage 1 — IoU ≥ iou_threshold  against ACTIVE tracks (lost == 0).
  Stage 2 — Centre distance ≤ max_distance against LOST tracks,
             using velocity-extrapolated predicted positions.
  Stage 3 — Graveyard re-ID: dead tracks kept for graveyard_frames more
             frames with a strict distance check. Lets a bird that briefly
             exits and re-enters get back its original ID.
"""

import numpy as np
from scipy.optimize import linear_sum_assignment


def _iou(a, b):
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    if inter == 0:
        return 0.0
    union = (a[2]-a[0])*(a[3]-a[1]) + (b[2]-b[0])*(b[3]-b[1]) - inter
    return inter / union if union > 0 else 0.0


def _center(bbox):
    return ((bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2)


def _distance(a, b):
    ax, ay = _center(a)
    bx, by = _center(b)
    return ((ax - bx) ** 2 + (ay - by) ** 2) ** 0.5


def _predict(track):
    """Extrapolate last bbox by stored velocity × frames lost."""
    x1, y1, x2, y2 = track["bbox"]
    vx, vy = track.get("vx", 0.0), track.get("vy", 0.0)
    n = track["lost"]
    return [x1 + vx * n, y1 + vy * n, x2 + vx * n, y2 + vy * n]


class BirdTracker:
    """
    Parameters
    ----------
    iou_threshold : float
        Min IoU to match a detection to an active track (stage 1).
    max_lost : int
        Frames a track survives in the active pool without a match.
    max_distance : float
        Max centre-to-centre pixel distance for lost-track re-match (stage 2).
    graveyard_frames : int
        Extra frames a dead track stays in the graveyard for stage-3 re-ID.
        Set to 0 to disable. Default: same as max_lost.
    graveyard_distance : float
        Stricter distance threshold used in the graveyard stage (stage 3).
    """

    def __init__(
        self,
        iou_threshold: float = 0.25,
        max_lost: int = 90,
        max_distance: float = 300.0,
        graveyard_frames: int = None,
        graveyard_distance: float = 200.0,
    ):
        self.iou_threshold = iou_threshold
        self.max_lost = max_lost
        self.max_distance = max_distance
        self.graveyard_frames = graveyard_frames if graveyard_frames is not None else max_lost
        self.graveyard_distance = graveyard_distance
        self._next_id: int = 1
        self._tracks: dict = {}
        # graveyard: tid → {"bbox", "vx", "vy", "ttl"}  (ttl counts down)
        self._graveyard: dict = {}

    def reset(self):
        self._next_id = 1
        self._tracks.clear()
        self._graveyard.clear()

    # ------------------------------------------------------------------

    def _apply_match(self, tid: int, det):
        """Update a track with a matched detection; refresh velocity."""
        t = self._tracks[tid]
        old = t["bbox"]
        new = list(det[:4])
        alpha = 0.5
        ocx, ocy = _center(old)
        ncx, ncy = _center(new)
        t["vx"] = alpha * (ncx - ocx) + (1 - alpha) * t.get("vx", 0.0)
        t["vy"] = alpha * (ncy - ocy) + (1 - alpha) * t.get("vy", 0.0)
        t["bbox"] = new
        t["conf"] = float(det[4])
        t["lost"] = 0
        t["age"] += 1

    def _revive(self, tid: int, det):
        """Bring a graveyard track back to life with a new detection."""
        g = self._graveyard.pop(tid)
        new = list(det[:4])
        ocx, ocy = _center(g["bbox"])
        ncx, ncy = _center(new)
        self._tracks[tid] = {
            "bbox": new,
            "conf": float(det[4]),
            "lost": 0,
            "age": g.get("age", 1) + 1,
            "vx": (ncx - ocx) * 0.5,
            "vy": (ncy - ocy) * 0.5,
        }

    def update(self, detections: list) -> list:
        """
        Parameters
        ----------
        detections : list of (x1, y1, x2, y2, conf)

        Returns
        -------
        list of (x1, y1, x2, y2, conf, track_id) — active tracks only
        """
        # ── Move expired tracks to graveyard ─────────────────────────
        expired = [tid for tid, t in self._tracks.items()
                   if t["lost"] > self.max_lost]
        for tid in expired:
            t = self._tracks.pop(tid)
            if self.graveyard_frames > 0:
                self._graveyard[tid] = {
                    "bbox": t["bbox"],
                    "vx": t.get("vx", 0.0),
                    "vy": t.get("vy", 0.0),
                    "age": t.get("age", 1),
                    "ttl": self.graveyard_frames,
                }

        # ── Age graveyard entries ─────────────────────────────────────
        dead_graves = [tid for tid, g in self._graveyard.items()
                       if g["ttl"] <= 0]
        for tid in dead_graves:
            del self._graveyard[tid]
        for g in self._graveyard.values():
            g["ttl"] -= 1

        if not detections:
            for t in self._tracks.values():
                t["lost"] += 1
            return []

        track_ids = list(self._tracks.keys())
        matched_det: set = set()
        matched_trk: set = set()

        # ── Stage 1 : IoU matching against ACTIVE tracks ─────────────
        active_ti = [i for i, tid in enumerate(track_ids)
                     if self._tracks[tid]["lost"] == 0]
        if active_ti:
            n_d = len(detections)
            iou_mat = np.zeros((n_d, len(active_ti)))
            for di, det in enumerate(detections):
                for col, ti in enumerate(active_ti):
                    iou_mat[di, col] = _iou(det[:4], self._tracks[track_ids[ti]]["bbox"])

            rows, cols = linear_sum_assignment(-iou_mat)
            for di, col in zip(rows, cols):
                if iou_mat[di, col] >= self.iou_threshold:
                    ti = active_ti[col]
                    self._apply_match(track_ids[ti], detections[di])
                    matched_det.add(di)
                    matched_trk.add(ti)

        # ── Stage 2 : Distance matching against LOST tracks ──────────
        lost_ti = [i for i, tid in enumerate(track_ids)
                   if self._tracks[tid]["lost"] > 0 and i not in matched_trk]
        unmatched_di = [di for di in range(len(detections)) if di not in matched_det]

        if lost_ti and unmatched_di:
            dist_mat = np.zeros((len(unmatched_di), len(lost_ti)))
            predicted = {i: _predict(self._tracks[track_ids[i]]) for i in lost_ti}

            for row, di in enumerate(unmatched_di):
                for col, ti in enumerate(lost_ti):
                    dist_mat[row, col] = _distance(detections[di][:4], predicted[ti])

            rows2, cols2 = linear_sum_assignment(dist_mat)
            for row, col in zip(rows2, cols2):
                if dist_mat[row, col] <= self.max_distance:
                    di = unmatched_di[row]
                    ti = lost_ti[col]
                    self._apply_match(track_ids[ti], detections[di])
                    matched_det.add(di)
                    matched_trk.add(ti)

        # ── Stage 3 : Graveyard re-ID ─────────────────────────────────
        unmatched_di2 = [di for di in range(len(detections)) if di not in matched_det]
        grave_ids = list(self._graveyard.keys())

        if grave_ids and unmatched_di2:
            dist_mat2 = np.zeros((len(unmatched_di2), len(grave_ids)))
            for row, di in enumerate(unmatched_di2):
                for col, tid in enumerate(grave_ids):
                    g = self._graveyard[tid]
                    n = self.graveyard_frames - g["ttl"]
                    pred = [
                        g["bbox"][0] + g["vx"] * n,
                        g["bbox"][1] + g["vy"] * n,
                        g["bbox"][2] + g["vx"] * n,
                        g["bbox"][3] + g["vy"] * n,
                    ]
                    dist_mat2[row, col] = _distance(detections[di][:4], pred)

            rows3, cols3 = linear_sum_assignment(dist_mat2)
            for row, col in zip(rows3, cols3):
                if dist_mat2[row, col] <= self.graveyard_distance:
                    di = unmatched_di2[row]
                    tid = grave_ids[col]
                    self._revive(tid, detections[di])
                    matched_det.add(di)

        # ── Increment lost counter for unmatched tracks ───────────────
        for ti, tid in enumerate(track_ids):
            if ti not in matched_trk:
                self._tracks[tid]["lost"] += 1

        # ── Create new tracks for unmatched detections ────────────────
        for di, det in enumerate(detections):
            if di not in matched_det:
                self._tracks[self._next_id] = {
                    "bbox": list(det[:4]),
                    "conf": float(det[4]),
                    "lost": 0,
                    "age": 1,
                    "vx": 0.0,
                    "vy": 0.0,
                }
                self._next_id += 1

        # ── Output: only currently visible tracks ─────────────────────
        output = []
        for tid in sorted(self._tracks.keys()):
            t = self._tracks[tid]
            if t["lost"] == 0:
                x1, y1, x2, y2 = t["bbox"]
                output.append((int(x1), int(y1), int(x2), int(y2), t["conf"], tid))

        return output

    @property
    def unique_ids_seen(self) -> int:
        return self._next_id - 1
