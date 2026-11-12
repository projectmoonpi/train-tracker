"""Cut a release: bump the version, date the CHANGELOG, commit, and tag.

    .venv/bin/python tools/release.py 0.2.0
    git push && git push origin v0.2.0      # the Release workflow builds it as a draft
    python3 tools/sign_release.py --release v0.2.0 --publish   # signs, publishes, removes older releases

Move your notes under "## [Unreleased]" in CHANGELOG.md first; they become the release notes.

The downloads carry the version in their names (US-Train-Tracker-for-Mac-v0.2.0.zip), so GitHub's fixed
"latest/download" address can't reach them: the README's and the guide's download links are pointed at this
release's files instead, and the guide's PDF is made again with them.
"""
import datetime
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INIT = ROOT / "src" / "train_tracker" / "__init__.py"
CHANGELOG = ROOT / "CHANGELOG.md"
README = ROOT / "README.md"
INSTALL = ROOT / "docs" / "INSTALL.md"
GUIDE_PDF = ROOT / "docs" / "US-Train-Tracker-Install-Guide.pdf"
FOLDER = re.compile(r"\*\*US Train Tracker(?: [\d.]+)? for (Mac|Windows)\*\*,")    # the zip's folder, in the guide
# a download link or name, versioned or not (the plain names are from before 1.0.1, the zips from before 1.0.3)
DOWNLOAD = re.compile(r"(?:releases/(?:latest/download|download/v[\d.]+)/)?(?:Install-)?US-Train-Tracker-for-(Mac|Windows)"
                      r"(?:-v[\d.]+)?\.(?:zip|dmg|exe)")
CO_AUTHOR = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"   # the project is built with Claude Code


def run(*cmd):
    subprocess.run(cmd, cwd=ROOT, check=True)


def point_downloads(version):
    """README.md and docs/INSTALL.md: download links, file names and the zip's folder name for this version."""
    def new(m):
        name = (f"US-Train-Tracker-for-Mac-v{version}.dmg" if m.group(1) == "Mac"
                else f"Install-US-Train-Tracker-for-Windows-v{version}.exe")      # (one file each, from 1.0.3)
        return f"releases/download/v{version}/{name}" if m.group(0).startswith("releases/") else name
    for f in (README, INSTALL):
        text = DOWNLOAD.sub(new, f.read_text())
        f.write_text(FOLDER.sub(lambda m: f"**US Train Tracker {version} for {m.group(1)}**,", text))


def main():
    if len(sys.argv) != 2 or not re.fullmatch(r"\d+\.\d+\.\d+", sys.argv[1]):
        sys.exit("usage: release.py X.Y.Z")
    version = sys.argv[1]
    if subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True).stdout.strip():
        sys.exit("working tree not clean: commit or stash first")

    log = CHANGELOG.read_text()
    m = re.search(r"## \[Unreleased\]\n(.*?)(?=\n## \[)", log, re.S)
    if not m or not m.group(1).strip():
        sys.exit("nothing under ## [Unreleased] in CHANGELOG.md")
    today = datetime.date.today().isoformat()
    CHANGELOG.write_text(log.replace("## [Unreleased]\n", f"## [Unreleased]\n\n## [{version}] - {today}\n", 1))
    INIT.write_text(re.sub(r'__version__ = ".*"', f'__version__ = "{version}"', INIT.read_text()))
    point_downloads(version)
    run("python3", str(ROOT / "tools" / "make_guide_pdf.py"))    # (reportlab: the Mac's python3 has it)

    run(sys.executable, "-m", "pytest", "-q")
    run("git", "add", str(INIT), str(CHANGELOG), str(README), str(INSTALL), str(GUIDE_PDF))
    run("git", "commit", "-m", f"Release v{version}\n\n{CO_AUTHOR}")
    run("git", "tag", "-a", f"v{version}", "-m", f"v{version}")
    print(f"\nTagged v{version}. Publish with:\n  git push && git push origin v{version}\n"
          "The Release workflow builds it as a draft. When it has finished, sign it, publish it and remove the older\n"
          f"releases (needs the release key on this Mac):\n  python3 tools/sign_release.py --release v{version} --publish")


if __name__ == "__main__":
    main()
