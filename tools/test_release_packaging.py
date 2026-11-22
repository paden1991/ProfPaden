"""Exercise bundled and single-addon release manifests, including rejection cases."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys, tempfile, zipfile
script = Path(__file__).with_name('build_release.py')
with tempfile.TemporaryDirectory(prefix='profpaden-packaging-') as directory:
    root = Path(directory)
    (root/'tools').mkdir(); shutil.copyfile(script, root/'tools/build_release.py')
    def addon(name, version):
        (root/name).mkdir()
        toc = f'## Interface: 16001\n## Version: {version}\nCore.lua\n'
        contents = {name+'.toc': toc.encode(), 'Core.lua': b'local addon = ...\n'}
        for path, data in contents.items(): (root/name/path).write_bytes(data)
        return {'addon': name, 'version': version, 'interface': 16001, 'files': [
            {'path': path, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'external': False}
            for path, data in contents.items()]}
    main = addon('ProfPaden', '1.0'); companion = addon('PadenCrates', '0.2.1-rc1')
    main['companions'] = [companion]
    checks = 0
    def run(success, tag='v1.0'):
        global checks
        (root/'source-manifest.json').write_text(json.dumps(main))
        env = dict(os.environ, GITHUB_REF_NAME=tag)
        result = subprocess.run([sys.executable, str(root/'tools/build_release.py')], env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        checks += 1
    run(True)
    with zipfile.ZipFile(root/'dist/ProfPaden-1.0-forever.zip') as z:
        assert set(z.namelist()) == {'ProfPaden/ProfPaden.toc','ProfPaden/Core.lua','PadenCrates/PadenCrates.toc','PadenCrates/Core.lua'}
        checks += 1
    run(False, 'v2.0')
    companion['files'][0]['external'] = True; run(False); companion['files'][0]['external'] = False
    companion['files'][0]['sha256'] = '0'*64; run(False)
    companion['files'][0]['sha256'] = hashlib.sha256((root/'PadenCrates/PadenCrates.toc').read_bytes()).hexdigest()
    companion['version'] = 'incorrect'; run(False); companion['version'] = '0.2.1-rc1'
    companion['files'][0]['path'] = '../outside'; run(False)
    main.pop('companions'); run(True)
    with zipfile.ZipFile(root/'dist/ProfPaden-1.0-forever.zip') as z:
        assert len(z.namelist()) == 2; checks += 1
    print(f'{checks} release packaging checks passed')
