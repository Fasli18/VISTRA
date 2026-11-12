#!/usr/bin/env python3
"""Build a new local runtime folder. Never connects to hosting, Git or a database."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
BACKEND_FILES = {
    'backend/.htaccess', 'backend/api.php', 'backend/admin.php',
    'backend/php/.htaccess', 'backend/php/db.php', 'backend/php/validator.php',
    'backend/php/security.php',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path,
                        help='New folder outside the project; existing folders are refused.')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if output == ROOT or ROOT in output.parents or output.exists():
        parser.error('Output must be a new folder outside the project.')
    names = [line.strip() for line in (ROOT / 'deployment/public-files.txt').read_text().splitlines()
             if line.strip() and not line.lstrip().startswith('#')]
    if len(names) != len(set(names)):
        parser.error('Duplicate entries in release allowlist.')
    entries = []
    for name in names:
        path = Path(name)
        allowed = name in {'.htaccess', 'index.html'} | BACKEND_FILES or (
            len(path.parts) == 2 and ((path.parts[0] == 'css' and path.suffix == '.css')
                                     or (path.parts[0] == 'js' and path.suffix == '.js')))
        source = ROOT / path
        if not allowed or path.is_absolute() or '..' in path.parts or not source.is_file() \
                or source.is_symlink() or ROOT not in source.resolve().parents:
            parser.error('Invalid/missing runtime file: ' + name)
        entries.append((name, source))
    for required in BACKEND_FILES | {'.htaccess', 'index.html'}:
        if required not in names:
            parser.error('Required runtime/protection file omitted: ' + required)
    output.mkdir(parents=True, mode=0o700)
    hashes = {}
    for name, source in entries:
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        hashes[name] = hashlib.sha256(target.read_bytes()).hexdigest()
    # Inventory stays beside the release folder, never inside the web root.
    output.with_name(output.name + '.manifest.json').write_text(json.dumps(hashes, indent=2) + '\n')
    print(f'Built {len(entries)} runtime files at {output}')
    print('Private config, SQL, diagnostics, reports, Git metadata and backups are excluded.')


if __name__ == '__main__':
    main()
