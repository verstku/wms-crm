"""Write the OpenAPI schema to a file without starting the server.

Usage: python -m app.export_openapi <path>
"""

import argparse
import json
from pathlib import Path

from app.main import app


def export_openapi(path: Path) -> None:
    # Deterministic output: check.sh and CI compare it byte for byte.
    path.write_text(
        json.dumps(app.openapi(), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export the OpenAPI schema to a JSON file.")
    parser.add_argument("path", type=Path)
    export_openapi(parser.parse_args().path)
