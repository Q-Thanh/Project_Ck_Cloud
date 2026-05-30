from __future__ import annotations

import json
import re
import time
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, UploadFile


BASE_DIR = Path(__file__).resolve().parent
DATASET_DIR = BASE_DIR / "dataset"
RAW_DIR = DATASET_DIR / "raw"
METADATA_DIR = DATASET_DIR / "metadata"
MAX_IMAGE_BYTES = 1_500_000

app = FastAPI(title="Mat AI Training Frame Collector")


def _safe_name(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_.-]+", "_", value.strip())
    return cleaned[:80] or "unknown"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/frames/low-confidence")
async def upload_low_confidence_frame(
    image: Annotated[UploadFile, File()],
    user_id: Annotated[str, Form()],
    detections: Annotated[str, Form()],
    model_version: Annotated[str, Form()] = "unknown",
    created_at: Annotated[str, Form()] = "",
    image_width: Annotated[int, Form()] = 0,
    image_height: Annotated[int, Form()] = 0,
) -> dict[str, str]:
    if image.content_type not in {"image/jpeg", "application/octet-stream"}:
        raise HTTPException(status_code=400, detail="Only JPEG images are accepted")

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image is empty")
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image is too large")

    try:
        parsed_detections = json.loads(detections)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="Invalid detections JSON") from exc

    safe_user_id = _safe_name(user_id)
    timestamp_ms = int(time.time() * 1000)
    filename = f"{safe_user_id}_{timestamp_ms}.jpg"
    user_raw_dir = RAW_DIR / safe_user_id
    user_raw_dir.mkdir(parents=True, exist_ok=True)
    METADATA_DIR.mkdir(parents=True, exist_ok=True)

    image_path = user_raw_dir / filename
    image_path.write_bytes(image_bytes)

    metadata = {
        "user_id": user_id,
        "image_path": str(image_path.relative_to(BASE_DIR)),
        "image_filename": filename,
        "image_width": image_width,
        "image_height": image_height,
        "model_version": model_version,
        "created_at": created_at,
        "received_at_ms": timestamp_ms,
        "status": "needs_labeling",
        "detections": parsed_detections,
    }

    metadata_path = METADATA_DIR / "low_confidence_frames.jsonl"
    with metadata_path.open("a", encoding="utf-8") as file:
        file.write(json.dumps(metadata, ensure_ascii=False) + "\n")

    return {
        "status": "saved",
        "image_path": metadata["image_path"],
        "metadata_path": str(metadata_path.relative_to(BASE_DIR)),
    }
