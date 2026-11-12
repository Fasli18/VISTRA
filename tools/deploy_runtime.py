#!/usr/bin/env python3
"""Validate VISTRA runtime; upload only with the explicit 'upload' subcommand."""
import argparse
import ftplib
import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
# Independent boundary: changing the public allowlist alone cannot add payloads.
EXPECTED = frozenset('''
.htaccess index.html
css/auth.css css/main.css css/vistra-midnight.css css/vistra-workspace.css
js/api-umkm.js js/api.js js/auth.js js/feedback-popup.js js/form.js
js/invitations.js js/main.js js/vistra-theme.js js/vistra-workspace.js
backend/.htaccess backend/api.php backend/admin.php backend/php/.htaccess
backend/php/db.php backend/php/validator.php backend/php/security.php
'''.split())
# Public account identifier used ONLY as an anti-misdirection guard.
# Authentication always uses VISTRA_FTP_USERNAME from GitHub Secrets.
EXPECTED_ACCOUNT = 'if0_43420750'
REMOTE_ROOT = '/htdocs'
PROTECTIONS = {
    '.htaccess': (
        'Options -Indexes', 'RewriteEngine On',
        r'RewriteRule (^|/)\.(?!well-known(?:/|$)) - [F,L,NC]',
        r'RewriteRule ^(?:docs|deployment|tools|tests?|backups?|logs?|node_modules|vendor)(?:/|$) - [F,L,NC]',
        r'RewriteRule ^backend/(?:php|migrations)(?:/|$) - [F,L,NC]',
        r'RewriteRule ^backend/(?:check_n8n_temp|test_n8n|test|tesadmin)\.php(?:/|$) - [F,L,NC]',
        'Require all denied',
    ),
    'backend/.htaccess': (
        'RewriteEngine On',
        r'RewriteRule ^(?:php|migrations)(?:/|$) - [F,L,NC]',
        r'RewriteRule ^(?:check_n8n_temp|test_n8n|test|tesadmin)\.php(?:/|$) - [F,L,NC]',
        'RewriteRule .* - [E=HTTP_AUTHORIZATION:%1]',
    ),
    'backend/php/.htaccess': ('Require all denied',),
}
SECRET_PATTERN = re.compile(
    r'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----|'
    r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b|'
    r'''(?i:define\s*\(\s*['"](?:DB_PASS(?:WORD)?|JWT_SECRET|FTP_PASSWORD)['"]\s*,\s*['"][^'"]+['"])'''
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_source():
    allowlist = ROOT / 'deployment/public-files.txt'
    require(not allowlist.is_symlink(), 'Allowlist must not be a symlink.')
    names = [line.strip() for line in allowlist.read_text().splitlines()
             if line.strip() and not line.lstrip().startswith('#')]
    require(len(names) == 22 and len(set(names)) == 22 and set(names) == EXPECTED,
            'Allowlist must match the approved 22 runtime files exactly.')
    tracked = set(subprocess.check_output(
        ['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0'))
    require('backend/php/config.php' not in tracked, 'Private config must not be tracked.')
    for name in names:
        source = ROOT / name
        require(name in tracked, 'Runtime file must be tracked: ' + name)
        require(source.is_file() and source.stat().st_size > 0,
                'Missing or empty runtime file: ' + name)
        require(not source.is_symlink() and source.resolve() == source,
                'Runtime paths must not contain symlinks: ' + name)
        require(not SECRET_PATTERN.search(source.read_text()),
                'Potential embedded credential in runtime file: ' + name)
    for name, required_lines in PROTECTIONS.items():
        lines = {line.strip() for line in (ROOT / name).read_text().splitlines()}
        require(set(required_lines) <= lines, 'Required protection changed: ' + name)
    root_rules = (ROOT / '.htaccess').read_text()
    require(r'config(?:\.[^/]+)?\.php' in root_rules and '<FilesMatch ' in root_rules,
            'Root config protection missing.')
    print('PASS: approved 22 tracked runtime files and required protection rules.')
    return names


def validate_release(release):
    names = validate_source()
    require(release.is_dir() and not release.is_symlink(), 'Release must be a real directory.')
    require(release.resolve() != ROOT and ROOT not in release.resolve().parents,
            'Release must be outside the checkout.')
    entries = list(release.rglob('*'))
    require(not any(path.is_symlink() for path in entries), 'Release contains a symlink.')
    actual = {path.relative_to(release).as_posix() for path in entries if path.is_file()}
    require(actual == EXPECTED, 'Release must contain exactly the 22 approved runtime files.')
    directories = {str(Path(name).parent) for name in names} - {'.'}
    require(all(path.is_file() or (path.is_dir() and
                path.relative_to(release).as_posix() in directories) for path in entries),
            'Unexpected directory or special file in release.')
    manifest = json.loads(release.with_name(release.name + '.manifest.json').read_text())
    require(set(manifest) == EXPECTED, 'Manifest file set mismatch.')
    for name in names:
        digest = hashlib.sha256((release / name).read_bytes()).hexdigest()
        require(digest == manifest[name] == hashlib.sha256((ROOT / name).read_bytes()).hexdigest(),
                'Release/source/manifest mismatch: ' + name)
    print('PASS: release inventory and all SHA-256 hashes; index.html at release root.')
    return names


def upload(release):
    names = validate_release(release)
    require(os.environ.get('GITHUB_ACTIONS') == 'true' and
            os.environ.get('GITHUB_REPOSITORY') == 'Fasli18/VISTRA' and
            os.environ.get('GITHUB_REF') == 'refs/heads/main',
            'Upload is restricted to Fasli18/VISTRA Actions on main.')
    host, username, password = [os.environ.get(key, '') for key in (
        'VISTRA_FTP_HOST', 'VISTRA_FTP_USERNAME', 'VISTRA_FTP_PASSWORD')]
    require(all((host, username, password)), 'Missing required VISTRA FTP secrets.')
    require(re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?', host),
            'FTP host must be a hostname without protocol, port or path.')
    require(username == EXPECTED_ACCOUNT, 'FTP username does not match the VISTRA account.')
    # TLS and certificate verification are mandatory; never fall back to plaintext.
    with ftplib.FTP_TLS(context=ssl.create_default_context(), timeout=60) as ftp:
        ftp.connect(host, 21)
        ftp.login(username, password)
        ftp.prot_p()
        ftp.set_pasv(True)
        # Fail if htdocs is absent: never create or guess a different document root.
        ftp.cwd(REMOTE_ROOT)
        require(ftp.pwd().rstrip('/') == REMOTE_ROOT, 'Unexpected FTP document root.')
        for directory in ('backend', 'backend/php', 'css', 'js'):
            target = REMOTE_ROOT + '/' + directory
            try:
                ftp.cwd(target)
            except ftplib.error_perm:
                ftp.mkd(target)
                ftp.cwd(target)
        # Protections first; the entry page is last. There is no remote listing,
        # download, delete, rename, mirror, sync state or config operation here.
        ordered = sorted(names, key=lambda name: (
            0 if name.endswith('.htaccess') else 2 if name == 'index.html' else 1, name))
        for name in ordered:
            target = REMOTE_ROOT + '/' + name
            with (release / name).open('rb') as source:
                ftp.storbinary('STOR ' + target, source)
            ftp.voidcmd('TYPE I')
            require(ftp.size(target) == (release / name).stat().st_size,
                    'Remote file size mismatch: ' + name)
            print('Uploaded and size-checked: ' + name)
    print('PASS: 22 runtime files uploaded; private production config untouched.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('validate-source', 'validate-release', 'upload'))
    parser.add_argument('--release', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'validate-source':
            validate_source()
        else:
            require(args.release is not None, '--release is required.')
            if args.command == 'validate-release':
                validate_release(args.release)
            else:
                upload(args.release)
    except Exception as error:
        # FTP server replies may echo sensitive values. Never print raw exceptions.
        message = str(error) if isinstance(error, ValueError) else type(error).__name__
        print('Deployment stopped: ' + message, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
