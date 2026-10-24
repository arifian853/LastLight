"""Fetch only the Windows template from the official, seekable release ZIP."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.7.2-stable"
SOURCE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}/Godot_v{VERSION}_export_templates.tpz"


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        response = urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60)
        self.url = response.url
        self.length = int(response.headers["Content-Length"])
        self.position = 0
        self.downloaded = 0

    def seekable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else (self.position + offset if whence == 1 else self.length + offset)
        return self.position

    def read(self, size=-1):
        if size < 0:
            size = self.length - self.position
        size = min(size, self.length - self.position)
        if size <= 0:
            return b""
        end = self.position + size - 1
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.position}-{end}"})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor the byte-range request")
            data = response.read()
        if len(data) != size:
            raise RuntimeError("Incomplete archive range")
        self.position += len(data)
        self.downloaded += len(data)
        return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path(".godot/release-tools"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    remote = RemoteZip(SOURCE)
    files = {}
    with zipfile.ZipFile(remote) as archive:
        for basename in ["version.txt", "windows_release_x86_64.exe"]:
            matches = [entry for entry in archive.infolist() if Path(entry.filename).name == basename]
            if len(matches) != 1:
                raise RuntimeError(f"Expected exactly one {basename}")
            data = archive.read(matches[0]) # ZipFile verifies the entry's CRC.
            (args.output / basename).write_bytes(data)
            files[basename] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
            print("Extracted", basename, len(data), "bytes", flush=True)
    for filename in ["LICENSE.txt", "COPYRIGHT.txt"]:
        url = f"https://raw.githubusercontent.com/godotengine/godot/{VERSION}/{filename}"
        data = urllib.request.urlopen(url, timeout=60).read()
        (args.output / ("GODOT_" + filename)).write_bytes(data)
    metadata = {"source": SOURCE, "version": VERSION, "archive_bytes": remote.length, "downloaded_bytes": remote.downloaded, "files": files}
    (args.output / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print("Downloaded", remote.downloaded, "of", remote.length, "archive bytes", flush=True)


if __name__ == "__main__":
    main()
