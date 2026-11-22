"""Build a reviewed Forever release with optional companion addon folders."""
from pathlib import Path, PurePosixPath
import hashlib, json, os, re, zipfile

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'source-manifest.json').read_text())
name, version = manifest['addon'], manifest['version']
tag = os.environ.get('GITHUB_REF_NAME', 'v' + version)
if tag != 'v' + version:
    raise SystemExit('Tag does not match the reviewed manifest version')

addons = [manifest] + manifest.get('companions', [])
blobs, folders = {}, set()
for addon in addons:
    folder, addon_version = addon['addon'], addon['version']
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', folder) or folder in folders:
        raise SystemExit('Invalid or duplicate addon folder')
    if addon['interface'] != 16001:
        raise SystemExit('Incorrect Forever manifest interface')
    folders.add(folder)
    files = {}
    for entry in addon['files']:
        if entry['external']:
            raise SystemExit('Public release blocked: local-only dependency remains')
        path = entry['path']
        rel = PurePosixPath(path)
        if rel.is_absolute() or '..' in rel.parts or ':' in path or chr(92) in path or str(rel) != path:
            raise SystemExit('Invalid manifest path')
        if path in files:
            raise SystemExit('Duplicate manifest file')
        blob = (root / folder / path).read_bytes()
        if len(blob) != entry['bytes'] or hashlib.sha256(blob).hexdigest() != entry['sha256']:
            raise SystemExit('Source hash or size changed: ' + folder + '/' + path)
        files[path] = blob
        blobs[folder + '/' + path] = blob
    toc = files[folder + '.toc'].decode('utf8')
    assert re.search(r'^## Interface:\s*16001\s*$', toc, re.M), 'Incorrect Forever interface'
    assert re.search(r'^## Version:\s*' + re.escape(addon_version) + r'\s*$', toc, re.M), 'Version mismatch'
    for line in toc.splitlines():
        if line.strip() and not line.startswith('#'):
            assert line.strip().replace(chr(92), '/') in files, line

out = root / 'dist'
out.mkdir(exist_ok=True)
filename = f'{name}-{version}-forever.zip'
target = out / filename
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path, blob in sorted(blobs.items()):
        info = zipfile.ZipInfo(path, (2026, 11, 2, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, blob)
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    assert {p.split('/')[0] for p in archive.namelist()} == folders
    assert set(archive.namelist()) == set(blobs)
    assert all(archive.read(path) == blob for path, blob in blobs.items())
metadata = {'releases': [{'name': version, 'filename': filename, 'nolib': False,
                         'metadata': [{'flavor': 'forever', 'interface': 16001}]}]}
(out / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf8')
digest = hashlib.sha256(target.read_bytes()).hexdigest()
(out / 'SHA256SUMS.txt').write_text(digest + '  ' + filename + '\n', encoding='utf8')
print(json.dumps({'archive': filename, 'addons': sorted(folders), 'files': len(blobs),
                  'sha256': digest, 'interface': 16001}))
