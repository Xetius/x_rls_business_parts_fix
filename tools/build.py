"""Builds x_rls_business_parts_fix_dev.zip with forward-slash paths. Run from the project folder."""
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "x_rls_business_parts_fix_dev.zip"
CONTENT = ["lua", "scripts", "mod_info", "LICENSE", "README.txt"]

with zipfile.ZipFile(OUTPUT, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in CONTENT:
        path = ROOT / name
        files = [path] if path.is_file() else sorted(p for p in path.rglob("*") if p.is_file())
        for file in files:
            archive.write(file, file.relative_to(ROOT).as_posix())
            print(file.relative_to(ROOT).as_posix())

print("built", OUTPUT, OUTPUT.stat().st_size)
