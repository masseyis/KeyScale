"""Build in isolation and verify the exact installable archive, using only stdlib."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CONTENTS = {"main.lua", "manifest.xml", "README.md", "cover.png", "thumbnail.png"}

with tempfile.TemporaryDirectory(prefix="keyscale-package-") as directory:
    destination = Path(directory)
    for name in CONTENTS | {"build.sh"}:
        shutil.copy2(ROOT / name, destination / name)
    subprocess.run(["bash", "build.sh"], cwd=destination, check=True)
    with zipfile.ZipFile(destination / "com.penchi.KeyScale.xrnx") as package:
        assert package.testzip() is None, "Corrupt package"
        assert set(package.namelist()) == CONTENTS, "Unexpected package contents"
        for name in CONTENTS:
            assert package.read(name) == (ROOT / name).read_bytes(), f"Stale packaged file: {name}"
        manifest = ET.fromstring(package.read("manifest.xml"))
        assert manifest.findtext("Id") == "com.penchi.KeyScale"
        assert manifest.findtext("ApiVersion") == "6"
        for element in ("ThumbnailPath", "CoverPath"):
            assert manifest.findtext(element) in CONTENTS, f"Missing image: {element}"
print("Renoise package contents, manifest and source freshness verified")
