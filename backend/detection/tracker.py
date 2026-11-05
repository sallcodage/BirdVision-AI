"""
BirdTracker — IoU-based multi-object tracker with track buffer.

Uses the Hungarian algorithm (scipy) for optimal frame-to-frame assignment.
Keeps lost tracks alive for `max_lost` frames so a bird that briefly
leaves the frame gets its ID back when it reappears nearby.

No external tracker library needed — only numpy + scipy (already installed).
"""

import numpy as np
from scipy.optimize import linear_sum_assignment


def _iou(a, b):
    """IoU between two boxes [x1, y1, x2, y2]."""
    x1 = max(a[0], b[0])
    y1 = max(a[1], b[1])
    x2 = min(a[2], b[2])
    y2 = min(a[3], b[3])
    inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    if inter == 0:
        return 0.0
    area_a = (a[2] - a[0]) * (a[3] - a[1])
    area_b = (b[2] - b[0]) * (b[3] - b[1])
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


class BirdTracker:
    """
    Multi-bird IoU tracker with configurable re-identification buffer.

    Parameters
    ----------
    iou_threshold : float
        Minimum IoU to match a detection to an existing track.
    max_lost : int
        Frames a track is kept alive after its last detection.
        90 frames ≈ 3 s at 30 fps — good for birds that briefly leave frame.
    """

    def __init__(self, iou_threshold: float = 0.25, max_lost: int = 90):
        self.iou_threshold = iou_threshold
        self.max_lost = max_lost
        self._next_id: int = 1
        # track_id → {"bbox": [x1,y1,x2,y2], "conf": float, "lost": int, "age": int}
        self._tracks: dict = {}

    def reset(self):
        self._next_id = 1
        self._tracks.clear()

    # ------------------------------------------------------------------

    def update(self, detections: list) -> list:
        """
        Parameters
        ----------
        detections : list of (x1, y1, x2, y2, conf)

        Returns
        -------
        list of (x1, y1, x2, y2, conf, track_id)
        """
        # Advance lost counters; prune dead tracks.
        dead = [tid for tid, t in self._tracks.items()
                if t["lost"] > self.max_lost]
        for tid in dead:
            del self._tracks[tid]

        if not detections:
            for t in self._tracks.values():
                t["lost"] += 1
            return []

        track_ids = list(self._tracks.keys())
        track_bboxes = [self._tracks[tid]["bbox"] for tid in track_ids]

        matched_det = set()   # detection indices matched to existing tracks
        matched_trk = set()   # track indices matched

        if track_bboxes:
            # IoU matrix  (n_det × n_tracks)
            n_d, n_t = len(detections), len(track_bboxes)
            iou_mat = np.zeros((n_d, n_t))
            for i, det in enumerate(detections):
                for j, tb in enumerate(track_bboxes):
                    iou_mat[i, j] = _iou(det[:4], tb)

            # Hungarian assignment
            det_idx, trk_idx = linear_sum_assignment(-iou_mat)

            for di, ti in zip(det_idx, trk_idx):
                if iou_mat[di, ti] >= self.iou_threshold:
                    tid = track_ids[ti]
                    self._tracks[tid]["bbox"] = list(detections[di][:4])
                    self._tracks[tid]["conf"] = float(detections[di][4])
                    self._tracks[tid]["lost"] = 0
                    self._tracks[tid]["age"] += 1
                    matched_det.add(di)
                    matched_trk.add(ti)

        # Increment lost for unmatched tracks.
        for ti, tid in enumerate(track_ids):
            if ti not in matched_trk:
                self._tracks[tid]["lost"] += 1

        # Create new tracks for unmatched detections.
        for di, det in enumerate(detections):
            if di not in matched_det:
                self._tracks[self._next_id] = {
                    "bbox": list(det[:4]),
                    "conf": float(det[4]),
                    "lost": 0,
                    "age": 1,
                }
                self._next_id += 1

        # Build output: only active tracks (lost == 0), in track-id order.
        output = []
        for tid in sorted(self._tracks.keys()):
            t = self._tracks[tid]
            if t["lost"] == 0:
                x1, y1, x2, y2 = t["bbox"]
                output.append((int(x1), int(y1), int(x2), int(y2), t["conf"], tid))

        return output

    @property
    def unique_ids_seen(self) -> int:
        """Total unique bird IDs ever assigned since last reset()."""
        return self._next_id - 1
