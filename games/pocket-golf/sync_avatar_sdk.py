#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Vendor the official SDK code only, pinned to a clean source revision."""
import argparse, hashlib, json, pathlib, subprocess

root = pathlib.Path(__file__).resolve().parent
target = root / 'addons/traineros'
names = ['avatar_client.gd', 'avatar_presenter.gd', 'avatar_exchange.gd', 'avatar_portrait.gd']
parser = argparse.ArgumentParser()
parser.add_argument('sdk', type=pathlib.Path, nargs='?')
parser.add_argument('--verify', action='store_true')
args = parser.parse_args()
digest = lambda data: hashlib.sha256(data.replace(b'\r\n', b'\n')).hexdigest()
record_path = target / 'avatar-sdk.json'
if args.verify:
    record = json.loads(record_path.read_text())
    for name in names:
        if digest((target / name).read_bytes()) != record['files'][name]:
            raise SystemExit('SDK copy differs: ' + name)
    print('Avatar SDK copies match', record['revision'])
else:
    if args.sdk is None:
        parser.error('Pass the TrainerOS SDK checkout')
    sdk = args.sdk.resolve()
    dirty = subprocess.check_output(['git', '-C', str(sdk), 'status', '--porcelain', '--', 'sdk/godot'], text=True)
    if dirty.strip():
        parser.error('Commit official SDK changes first')
    revision = subprocess.check_output(['git', '-C', str(sdk), 'rev-parse', 'HEAD'], text=True).strip()
    hashes = {}
    for name in names:
        data = (sdk / 'sdk/godot' / name).read_bytes().replace(b'\r\n', b'\n')
        (target / name).write_bytes(data)
        hashes[name] = digest(data)
    record_path.write_text(json.dumps({'repository': 'https://github.com/EriArk/TrainerOS',
        'revision': revision, 'license': 'GPL-3.0-or-later', 'normalization': 'LF', 'files': hashes}, indent=2) + '\n')
    print('Pinned official SDK', revision)
