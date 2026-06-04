from __future__ import annotations

import argparse
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATASET_DIR = PROJECT_ROOT / "backend" / "dataset"
OUTPUT_DIR = PROJECT_ROOT / "exports"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default=str(OUTPUT_DIR / "mat_ai_backend_dataset.zip"),
        help="Output zip path",
    )
    args = parser.parse_args()

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if not DATASET_DIR.exists():
        raise SystemExit(f"Dataset directory does not exist: {DATASET_DIR}")

    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as zip_file:
        for path in DATASET_DIR.rglob("*"):
            if path.is_file():
                zip_file.write(path, path.relative_to(DATASET_DIR.parent))

    print(f"Packed dataset to {output_path}")


if __name__ == "__main__":
    main()
