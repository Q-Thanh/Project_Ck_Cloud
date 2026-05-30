from __future__ import annotations

import argparse
import random
import shutil
from pathlib import Path

from common import MANIFEST_PATH, PRELABEL_DIR, REVIEWED_LABEL_DIR, YOLO_DIR, load_classes, read_jsonl


def _label_path_for(image_path: str, use_prelabels: bool) -> Path:
    label_dir = PRELABEL_DIR if use_prelabels else REVIEWED_LABEL_DIR
    return label_dir / f"{Path(image_path).stem}.txt"


def _copy_pair(row: dict, label_path: Path, split: str) -> None:
    source_image = Path(row["absolute_image_path"])
    image_target = YOLO_DIR / "images" / split / source_image.name
    label_target = YOLO_DIR / "labels" / split / label_path.name
    image_target.parent.mkdir(parents=True, exist_ok=True)
    label_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_image, image_target)
    shutil.copy2(label_path, label_target)


def _write_data_yaml(classes: list[str]) -> None:
    names = ", ".join(f'"{name}"' for name in classes)
    data_yaml = "\n".join(
        [
            f"path: {YOLO_DIR}",
            "train: images/train",
            "val: images/val",
            f"nc: {len(classes)}",
            f"names: [{names}]",
            "",
        ]
    )
    (YOLO_DIR / "data.yaml").write_text(data_yaml, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--use-prelabels", action="store_true", help="Export draft labels instead of reviewed labels")
    parser.add_argument("--val-ratio", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rows = read_jsonl(MANIFEST_PATH)
    eligible_rows = []
    for row in rows:
        label_path = _label_path_for(row["image_path"], args.use_prelabels)
        if Path(row["absolute_image_path"]).exists() and label_path.exists():
            eligible_rows.append((row, label_path))

    random.Random(args.seed).shuffle(eligible_rows)
    val_count = round(len(eligible_rows) * args.val_ratio)
    val_items = set(range(val_count))

    if YOLO_DIR.exists():
        shutil.rmtree(YOLO_DIR)

    for index, (row, label_path) in enumerate(eligible_rows):
        split = "val" if index in val_items else "train"
        _copy_pair(row, label_path, split)

    _write_data_yaml(load_classes())
    print(f"Exported {len(eligible_rows)} images to {YOLO_DIR}")
    print(f"Train: {len(eligible_rows) - val_count}, Val: {val_count}")


if __name__ == "__main__":
    main()
