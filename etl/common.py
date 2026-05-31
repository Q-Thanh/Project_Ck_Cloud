from __future__ import annotations

import json
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BACKEND_DIR = PROJECT_ROOT / "backend"
DATASET_DIR = BACKEND_DIR / "dataset"
METADATA_PATH = DATASET_DIR / "metadata" / "low_confidence_frames.jsonl"
PROCESSED_DIR = DATASET_DIR / "processed"
MANIFEST_PATH = PROCESSED_DIR / "manifest.jsonl"
PRELABEL_DIR = DATASET_DIR / "prelabels"
REVIEWED_LABEL_DIR = DATASET_DIR / "reviewed_labels"
YOLO_DIR = DATASET_DIR / "yolo"
LABELS_PATH = PROJECT_ROOT / "assets" / "labels.txt"


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []

    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as file:
        for line_number, line in enumerate(file, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise ValueError(f"Invalid JSON at {path}:{line_number}") from exc
    return rows


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        for row in rows:
            file.write(json.dumps(row, ensure_ascii=False) + "\n")


def load_classes() -> list[str]:
    if not LABELS_PATH.exists():
        return []
    return [
        line.strip()
        for line in LABELS_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def resolve_backend_path(relative_path: str) -> Path:
    return BACKEND_DIR / relative_path
