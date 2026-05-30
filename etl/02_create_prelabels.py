from __future__ import annotations

from pathlib import Path

from common import MANIFEST_PATH, PRELABEL_DIR, load_classes, read_jsonl


def _to_yolo_box(box: list[float], image_width: int, image_height: int) -> tuple[float, float, float, float] | None:
    if len(box) < 4 or image_width <= 0 or image_height <= 0:
        return None

    x1, y1, x2, y2 = [float(value) for value in box[:4]]

    if x2 <= 2.0 and y2 <= 2.0:
        x_center = (x1 + x2) / 2
        y_center = (y1 + y2) / 2
        width = x2 - x1
        height = y2 - y1
    else:
        x_center = ((x1 + x2) / 2) / image_width
        y_center = ((y1 + y2) / 2) / image_height
        width = (x2 - x1) / image_width
        height = (y2 - y1) / image_height

    values = [x_center, y_center, width, height]
    if any(value < 0 or value > 1 for value in values):
        return None
    if width <= 0 or height <= 0:
        return None

    return x_center, y_center, width, height


def main() -> None:
    classes = load_classes()
    class_to_id = {name: index for index, name in enumerate(classes)}
    rows = read_jsonl(MANIFEST_PATH)
    PRELABEL_DIR.mkdir(parents=True, exist_ok=True)

    written = 0
    for row in rows:
        image_path = Path(row["image_path"])
        image_width = int(row.get("image_width") or 0)
        image_height = int(row.get("image_height") or 0)
        label_lines: list[str] = []

        for detection in row.get("detections", []):
            tag = detection.get("tag")
            box = detection.get("box") or []
            if tag not in class_to_id:
                continue

            yolo_box = _to_yolo_box(box, image_width, image_height)
            if yolo_box is None:
                continue

            x_center, y_center, width, height = yolo_box
            label_lines.append(
                f"{class_to_id[tag]} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}"
            )

        if not label_lines:
            continue

        output_path = PRELABEL_DIR / f"{image_path.stem}.txt"
        output_path.write_text("\n".join(label_lines) + "\n", encoding="utf-8")
        written += 1

    print(f"Wrote {written} prelabel files to {PRELABEL_DIR}")


if __name__ == "__main__":
    main()
