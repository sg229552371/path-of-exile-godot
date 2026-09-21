"""Spike: slice icon sheets into individual icons (connected-component based).

Finds non-background blobs, crops each with padding, keys out the cream
background via flood-fill from the crop edges (preserves interior colors).
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

BG = np.array([242, 232, 208])  # cream #f2e8d0


def slice_sheet(src: str, out_dir: str, prefix: str, count: int, order: str = "row") -> list:
    img = Image.open(src).convert("RGB")
    arr = np.asarray(img).astype(int)
    # distance from bg color -> mask of "icon" pixels
    dist = np.abs(arr - BG).sum(axis=2)
    mask = dist > 60
    # drop tiny specks
    mask = ndimage.binary_opening(mask, structure=np.ones((5, 5)))
    labels, n = ndimage.label(mask)
    boxes = ndimage.find_objects(labels)
    comps = []
    for i, sl in enumerate(boxes):
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if h < 40 or w < 40:  # noise
            continue
        cy = (sl[0].start + sl[0].stop) / 2
        cx = (sl[1].start + sl[1].stop) / 2
        comps.append((cx, cy, sl))
    # sort: row-major or column-major
    if order == "row":
        comps.sort(key=lambda c: (round(c[1] / 200), c[0]))
    else:
        comps.sort(key=lambda c: (round(c[0] / 200), c[1]))
    comps = comps[:count]
    outs = []
    for idx, (_, _, sl) in enumerate(comps):
        pad = 6
        y0 = max(0, sl[0].start - pad)
        y1 = min(arr.shape[0], sl[0].stop + pad)
        x0 = max(0, sl[1].start - pad)
        x1 = min(arr.shape[1], sl[1].stop + pad)
        crop = arr[y0:y1, x0:x1]
        rgba = _key_bg(crop)
        out = f"{out_dir}/{prefix}_{idx}.png"
        Image.fromarray(rgba).save(out)
        outs.append(out)
    return outs


def _key_bg(crop: np.ndarray) -> np.ndarray:
    """Flood-fill background from crop edges -> alpha 0 (keeps interior cream)."""
    h, w, _ = crop.shape
    dist = np.abs(crop - BG).sum(axis=2)
    bg_like = dist < 90
    lbl, _ = ndimage.label(bg_like)
    edge_labels = set(np.unique(np.concatenate([lbl[0], lbl[-1], lbl[:, 0], lbl[:, -1]])))
    edge_labels.discard(0)
    alpha = np.full((h, w), 255, dtype=np.uint8)
    if edge_labels:
        edge_mask = np.isin(lbl, list(edge_labels))
        alpha[edge_mask] = 0
        # feather 1px
        from scipy import ndimage as ndi
        eroded = ndi.binary_erosion(edge_mask)
        alpha[eroded] = 0
    return np.dstack([crop.astype(np.uint8), alpha])


if __name__ == "__main__":
    base = r"D:\AI-game-All\TESt-GAMe\流放之路\assets\_spike\shop"
    # items sheet: icons sit in a bottom row, boxed; 1 row 4 cols, row order
    a = slice_sheet(f"{base}\\sheet_items.png", base, "item", 4, order="row")
    # weapons sheet: 2x4 grid; take sword, spear, bow, staff, hammer, shuriken
    # layout per image: row0 = sword, spear, bow, staff; row1 = staff2, staff3, hammer, shuriken
    b = slice_sheet(f"{base}\\sheet_weapons.png", base, "wpn", 8, order="row")
    print("items:", a)
    print("weapons:", b)
