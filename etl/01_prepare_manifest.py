from __future__ import annotations

from common import MANIFEST_PATH, METADATA_PATH, read_jsonl, resolve_backend_path, write_jsonl


def main() -> None:
    rows = read_jsonl(METADATA_PATH)
    manifest = []
    seen_paths: set[str] = set()

    for row in rows:
        image_path = row.get("image_path")
        if not image_path or image_path in seen_paths:
            continue

        absolute_image_path = resolve_backend_path(image_path)
        if not absolute_image_path.exists():
            continue

        detections = row.get("detections") or []
        manifest.append(
            {
                "image_path": image_path,
                "absolute_image_path": str(absolute_image_path),
                "image_filename": row.get("image_filename", absolute_image_path.name),
                "image_width": row.get("image_width", 0),
                "image_height": row.get("image_height", 0),
                "user_id": row.get("user_id", ""),
                "model_version": row.get("model_version", ""),
                "created_at": row.get("created_at", ""),
                "received_at_ms": row.get("received_at_ms", 0),
                "status": "needs_review",
                "detections": detections,
                "detection_count": len(detections),
            }
        )
        seen_paths.add(image_path)

    write_jsonl(MANIFEST_PATH, manifest)
    print(f"Wrote {len(manifest)} records to {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
