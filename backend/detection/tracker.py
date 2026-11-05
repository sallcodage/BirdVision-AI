"""
BirdTracker — IoU + velocity re-identification tracker.

Two-stage matching:
  Stage 1 — IoU ≥ iou_threshold  against active tracks (last seen this frame).
  Stage 2 — Centre distance ≤ max_distance against LOST tracks, using
             velocity-extrapolated predicted positions.

A bird that exits and re-enters within max_lost frames at a nearby position
gets its old tracker ID back instead of a new one.
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
        Frames a track survives without a match before being deleted.
        90 ≈ 3 s at 30 fps.
    max_distance : float
        Max centre-to-centre pixel distance to re-match a lost track (stage 2).
        150 px works well for 640×640 images.
    """

    def __init__(
        self,
        iou_threshold: float = 0.25,
        max_lost: int = 90,
        max_distance: float = 150.0,
    ):
        self.iou_threshold = iou_threshold
        self.max_lost = max_lost
        self.max_distance = max_distance
        self._next_id: int = 1
        self._tracks: dict = {}

    def reset(self):
        self._next_id = 1
        self._tracks.clear()

    # ------------------------------------------------------------------

    def _apply_match(self, tid: int, det):
        """Update a track with a matched detection; refresh velocity."""
        t = self._tracks[tid]
        old = t["bbox"]
        new = list(det[:4])
        # Exponential moving average of velocity (α=0.5 smooths jitter)
        alpha = 0.5
        ocx, ocy = _center(old)
        ncx, ncy = _center(new)
        t["vx"] = alpha * (ncx - ocx) + (1 - alpha) * t.get("vx", 0.0)
        t["vy"] = alpha * (ncy - ocy) + (1 - alpha) * t.get("vy", 0.0)
        t["bbox"] = new
        t["conf"] = float(det[4])
        t["lost"] = 0
        t["age"] += 1

    def update(self, detections: list) -> list:
        """
        Parameters
        ----------
        detections : list of (x1, y1, x2, y2, conf)

        Returns
        -------
        list of (x1, y1, x2, y2, conf, track_id)  — active tracks only
        """
        # Prune tracks that have been lost too long
        dead = [tid for tid, t in self._tracks.items()
                if t["lost"] > self.max_lost]
        for tid in dead:
            del self._tracks[tid]

        if not detections:
            for t in self._tracks.values():
                t["lost"] += 1
            return []

        track_ids = list(self._tracks.keys())
        matched_det: set = set()
        matched_trk: set = set()   # indices into track_ids

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
        unmatched_di = [di for di in range(len(detections))
                        if di not in matched_det]

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
