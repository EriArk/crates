#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Lossless packaging of selected Quaternius glTF files; no rig/pose edits.
Usage: import_residents.py path/to/original/monsters.zip [path/to/characters.zip]
The archive mirror and original author/license URLs are recorded in provenance.
"""
import base64, hashlib, json, struct, sys, zipfile
from pathlib import Path
def package_glb(original):
    document = json.loads(original)
    assert len(document['buffers']) == 1
    data = base64.b64decode(document['buffers'][0].pop('uri').split(',')[1])
    encoded = json.dumps(document, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    data += b'\0' * (-len(data) % 4)
    glb = struct.pack('<III', 0x46546c67, 2, 28 + len(encoded) + len(data))
    glb += struct.pack('<II', len(encoded), 0x4e4f534a) + encoded
    glb += struct.pack('<II', len(data), 0x004e4942) + data
    return glb

root = Path(__file__).resolve().parents[1]
archive = Path(sys.argv[1])
destination = root / 'assets/residents'
destination.mkdir(parents=True, exist_ok=True)
manifest = {
    'author': 'Quaternius', 'pack': 'Ultimate Monsters (October 2022)',
    'source': 'https://quaternius.com/packs/ultimatemonsters.html',
    'original_folder': 'https://drive.google.com/drive/folders/18m4KpzpEzhC9wl7jzr6dUc0N8Jozr79C',
    'download': 'https://herni-studio-tokoupim.cz/asset-knihovna/soubory/quaternius-ultimatemonsters/data.zip',
    'download_note': 'Public CC0 mirror used because the author-linked Drive download reported quota exceeded.',
    'downloaded': '2026-11-14', 'license': 'CC0-1.0',
    'license_note': 'Supplied License.txt says Ultimate Platformer Pack; retained verbatim. The Ultimate Monsters author page also explicitly specifies CC0.',
    'archive_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
    'conversion': 'Embedded base64 buffer repackaged as GLB without changing meshes, skins, materials or animations.',
    'files': {}
}
with zipfile.ZipFile(archive) as z:
    for name, source in [('Bunny', 'Big/glTF/Bunny.gltf'), ('Yeti', 'Big/glTF/Yeti.gltf'), ('Pigeon', 'Flying/glTF/Pigeon.gltf')]:
        original = z.read(source)
        glb = package_glb(original)
        (destination / (name + '.glb')).write_bytes(glb)
        manifest['files'][name + '.glb'] = {'original_path': source, 'original_sha256': hashlib.sha256(original).hexdigest(), 'sha256': hashlib.sha256(glb).hexdigest()}
    (root / 'licenses/Quaternius-Monsters-CC0.txt').write_bytes(z.read('License.txt'))
(destination / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')

if len(sys.argv) > 2:
    archive = Path(sys.argv[2])
    manifest.update({
        'pack': 'Ultimate Animated Character Pack (November 2019)',
        'source': 'https://quaternius.com/packs/ultimatedanimatedcharacter.html',
        'original_folder': 'https://drive.google.com/drive/folders/1sNi1AfenfPRrvRt5yfaj5QMMd6KKcUJ5',
        'download': 'https://herni-studio-tokoupim.cz/asset-knihovna/soubory/quaternius-ultimatedanimatedcharacter/data.zip',
        'license_note': 'Supplied source license and original author page both specify CC0.',
        'archive_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'files': {}
    })
    with zipfile.ZipFile(archive) as z:
        for name in ['Casual_Female', 'Casual_Male', 'Chef_Female', 'Kimono_Female', 'OldClassy_Male', 'Wizard', 'Witch']:
            source = 'Source/glTF/' + name + '.gltf'
            original = z.read(source)
            glb = package_glb(original)
            (destination / (name + '.glb')).write_bytes(glb)
            manifest['files'][name + '.glb'] = {'original_path': source, 'original_sha256': hashlib.sha256(original).hexdigest(), 'sha256': hashlib.sha256(glb).hexdigest()}
        (root / 'licenses/Quaternius-Characters-CC0.txt').write_bytes(z.read('Source/License.txt'))
    (destination / 'humans-provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
