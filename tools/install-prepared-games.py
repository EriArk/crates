#!/usr/bin/env python3
"""Owner-authorized device update using the installed Crates Store, no catalogue publication.

Run on a handheld: script STAGE INSTALLED_HELPERS. STAGE contains manifest.json:
[{record: basename, archive: basename}]. Private before/after receipts stay there.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sqlite3
import sys

p = argparse.ArgumentParser()
p.add_argument('stage', type=Path)
p.add_argument('helpers', type=Path)
a = p.parse_args()
stage = a.stage.resolve()
sys.path.insert(0, str(a.helpers.resolve()))
from installer import Store, validate_records

base = Path.home()/'.local/share/TrainerOS/TrainerOS'
store = Store(base/'crates')
entries = json.loads((stage/'manifest.json').read_text())
for entry in entries:
    for key in ('record', 'archive'):
        assert Path(entry[key]).name == entry[key], 'Stage basename required'
records = [json.loads((stage/e['record']).read_text()) for e in entries]
validate_records(records)
assert len({r['id'] for r in records}) == len(records)
assert all(r['kind'] == 'game' for r in records)

def snapshot():
    files = {}
    for record in records:
        for f in (store.root/'data'/record['id']).rglob('*'):
            if f.is_file():
                files[str(f.relative_to(store.root/'data'))] = hashlib.sha256(f.read_bytes()).hexdigest()
    with sqlite3.connect('file:'+str(base/'traineros.sqlite3')+'?mode=ro', uri=True) as db:
        assert db.execute('pragma quick_check').fetchone()[0] == 'ok'
        history = list(db.execute('select count(*),max(started_at) from play_sessions').fetchone())
    return {'receipts': store.installed(), 'data': files, 'history': history}

before = snapshot()
assert not (stage/'before.json').exists(), 'Use a fresh stage; never replace a rollback snapshot'
assert all(r['id'] in before['receipts'] for r in records), 'Only update installed games'
for entry, record in zip(entries, records):
    old = before['receipts'][record['id']]['version']
    assert tuple(map(int, record['version'].split('.'))) > tuple(map(int, old.split('.'))), 'Refuse a downgrade or duplicate update'
    archive = stage/entry['archive']
    assert archive.stat().st_size == record['size']
    with archive.open('rb') as stream:
        assert hashlib.file_digest(stream, 'sha256').hexdigest() == record['sha256']
# Store owns extraction, checksums, architecture, active-game locks and atomic receipts.
# Preserve previous immutable objects for rollback; never delete user data.
(stage/'before.json').write_text(json.dumps(before))
for entry, record in zip(entries, records):
    result = store.activate(stage/entry['archive'], record)
    assert result['previousObject'] == before['receipts'][record['id']]['object']
    print('UPDATED', record['id'], record['version'], flush=True)
after = snapshot()
assert before['data'] == after['data'], 'Game data changed during installation'
assert before['history'] == after['history'], 'History changed during installation'
changed = {r['id'] for r in records}
assert all(after['receipts'][key] == value for key, value in before['receipts'].items() if key not in changed)
assert all((store.root/'objects'/before['receipts'][key]['object']).is_dir() for key in changed)
(stage/'after.json').write_text(json.dumps(after))
report = {'versions': {r['id']: r['version'] for r in records}, 'data_preserved': True,
          'history_preserved': True, 'other_packages_unchanged': True, 'rollback_objects_retained': True,
          'package_sha256': {r['id']: r['sha256'] for r in records}}
(stage/'installation.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report))
