from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ETL_DIR = Path(__file__).resolve().parent


def _run(script_name: str, *args: str) -> None:
    command = [sys.executable, str(ETL_DIR / script_name), *args]
    subprocess.run(command, check=True)


def main() -> None:
    _run("01_prepare_manifest.py")
    _run("02_create_prelabels.py")
    print("ETL preparation completed. Review labels before exporting YOLO dataset.")
    print("For quick testing only: python3 etl/03_export_yolo_dataset.py --use-prelabels")


if __name__ == "__main__":
    main()
