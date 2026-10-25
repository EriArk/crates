#!/usr/bin/env python3
"""Changing simulation/content requires a new immutable server ruleset."""
import hashlib
import json
from pathlib import Path
import re

def verify(root):
    manifest=json.loads((root/'docs/scorecard-sources.json').read_text())
    files=manifest['source_sha256']
    assert set(files)=={'scripts/rules.gd','scripts/courses.gd','scripts/ball_physics.gd','scripts/green_surface.gd','scripts/dimensions.gd'}
    for name,expected in files.items():
        text=(root/name).read_text(encoding='utf-8')
        assert hashlib.sha256(text.encode()).hexdigest()==expected, f'Rules changed: {name}; register a new ruleset'
        dependencies=re.findall(r'preload\("res://([^\"]+)"\)',text)
        assert all(dep in files for dep in dependencies), 'Untracked simulation dependency'
    digest=hashlib.sha256('\n'.join(f'{name} {files[name]}' for name in sorted(files)).encode()).hexdigest()
    assert manifest['content_id']=='island-'+digest[:48]
    assert f'const RULESET := "{manifest["ruleset"]}"' in (root/'scripts/scorecards.gd').read_text()
    assert 'const CAP = 8' in (root/'scripts/rules.gd').read_text()
    print('Immutable Golf simulation/content binding verified')

if __name__=='__main__':verify(Path(__file__).resolve().parents[1])
