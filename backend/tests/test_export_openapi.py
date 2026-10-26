import json
import subprocess
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]


def test_export_openapi_writes_schema(tmp_path: Path) -> None:
    target = tmp_path / "openapi.json"

    subprocess.run(
        [sys.executable, "-m", "app.export_openapi", str(target)], cwd=BACKEND_DIR, check=True
    )

    text = target.read_text(encoding="utf-8")
    assert text.endswith("}\n")
    responses = json.loads(text)["paths"]["/api/health"]["get"]["responses"]
    assert {"200", "503"} <= responses.keys()
