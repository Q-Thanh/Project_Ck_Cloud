from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from package_dataset_for_databricks import OUTPUT_DIR, main as package_dataset


DEFAULT_ZIP = OUTPUT_DIR / "mat_ai_backend_dataset.zip"
DEFAULT_VOLUME_DIR = "/Volumes/workspace/default/mat_ai_backend/exports"


def _to_cli_volume_path(path: str) -> str:
    if path.startswith("dbfs:/") or path.startswith("s3://") or path.startswith("abfss://"):
        return path
    if path.startswith("/Volumes/"):
        return f"dbfs:{path}"
    return path


def _run(command: list[str]) -> None:
    print("+", " ".join(command))
    subprocess.run(command, check=True)


def _require_databricks_cli() -> None:
    if shutil.which("databricks") is None:
        raise SystemExit(
            "Databricks CLI is not installed.\n"
            "Install it with: brew install databricks\n"
            "Then configure it with: databricks configure"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Package local backend/dataset, upload it to a Databricks Volume, and optionally run an ETL job.",
    )
    parser.add_argument(
        "--zip-path",
        default=str(DEFAULT_ZIP),
        help="Local zip path to create and upload.",
    )
    parser.add_argument(
        "--volume-dir",
        default=DEFAULT_VOLUME_DIR,
        help="Databricks Volume directory that receives the zip.",
    )
    parser.add_argument(
        "--job-id",
        default="",
        help="Optional Databricks job id to run after upload.",
    )
    args = parser.parse_args()

    _require_databricks_cli()

    zip_path = Path(args.zip_path)
    package_dataset_args = sys.argv[:1] + ["--output", str(zip_path)]
    original_argv = sys.argv
    try:
        sys.argv = package_dataset_args
        package_dataset()
    finally:
        sys.argv = original_argv

    cli_volume_dir = _to_cli_volume_path(args.volume_dir.rstrip("/"))
    remote_zip = f"{cli_volume_dir}/{zip_path.name}"
    _run(["databricks", "fs", "mkdirs", cli_volume_dir])
    _run(["databricks", "fs", "cp", str(zip_path), remote_zip, "--overwrite"])

    if args.job_id:
        _run(["databricks", "jobs", "run-now", str(args.job_id)])

    print("Done.")
    print(f"Uploaded: {remote_zip}")
    if args.job_id:
        print(f"Triggered Databricks job: {args.job_id}")


if __name__ == "__main__":
    main()
