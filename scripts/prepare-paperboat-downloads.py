#!/usr/bin/env python3
"""Prepare immutable, verified downloads before PaperBoat configures offline."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(build, lock):
    if set(lock['fetchedFiles']) != set(lock['fetchedFileUrls']):
        raise ValueError('Every fetched file must have a pinned URL and checksum')
    for name, digest in lock['fetchedFiles'].items():
        target = build / name
        if target.is_file() and sha256(target) == digest:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        # Replace a stale/failed download only after the replacement is verified.
        # A failed attempt never truncates an existing file or leaves partial data.
        for attempt in range(3):
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(dir=target.parent, prefix=target.name + '.',
                                                 suffix='.partial', delete=False) as output:
                    temporary = Path(output.name)
                    with urllib.request.urlopen(lock['fetchedFileUrls'][name], timeout=30) as response:
                        while True:
                            chunk = response.read(64 * 1024)
                            if not chunk:
                                break
                            output.write(chunk)
                if sha256(temporary) != digest:
                    raise ValueError('Downloaded file hash mismatch: ' + name)
                temporary.replace(target)
                break
            except (OSError, ValueError):
                if attempt == 2:
                    raise
                time.sleep(attempt + 1)
            finally:
                if temporary is not None and temporary.exists():
                    temporary.unlink()
    print('All %d PaperBoat downloads match their locked contents.' % len(lock['fetchedFiles']))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, required=True)
    args = parser.parse_args()
    lock = json.loads((ROOT / 'paperboat.lock.json').read_text(encoding='utf-8'))
    prepare(args.build_dir, lock)


if __name__ == '__main__':
    main()
