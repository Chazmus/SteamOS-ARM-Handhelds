#!/usr/bin/env python3
"""Build a verified offline update bundle from a completed rootfs and boot image."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import importlib.util

_spec = importlib.util.spec_from_file_location(
    'konkr_update', Path(__file__).resolve().parent.parent / 'external-and-mods/konkr-update/konkr-update.py')
_updater = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_updater)

ap = argparse.ArgumentParser()
ap.add_argument('--rootfs', required=True)
ap.add_argument('--kernel', required=True)
ap.add_argument('--soc', default='sm8650', choices=sorted(_updater.SOC_MODELS))
ap.add_argument('--version', required=True)
ap.add_argument('--output', required=True)
a = ap.parse_args()
root = Path(a.rootfs).resolve(); output = Path(a.output).resolve()
if not (root / 'usr/lib/liblsfg-vk-layer-arm64.so').is_file(): raise SystemExit('missing LSFG v2 ARM layer')
with tempfile.TemporaryDirectory(prefix='konkr-package-', dir=output.parent) as temp:
    stage = Path(temp)
    def copy(src, dst):
        dst.mkdir(parents=True, exist_ok=True)
        # The completed build tree must remain unchanged throughout packaging.
        # Same-filesystem hard links retain exact metadata without another full copy.
        if src.stat().st_dev == dst.stat().st_dev:
            subprocess.run(['cp', '-a', '--link', str(src) + '/.', str(dst) + '/'], check=True)
        else:
            subprocess.run(['rsync', '-aHAX', '--numeric-ids', str(src) + '/', str(dst) + '/'], check=True)
    for rel in ('usr', 'opt', 'etc', 'var/lib/overlays/etc/upper'):
        src = root / rel
        if src.exists(): copy(src, stage / 'root' / rel)
    for name in ('konkr-control', 'decky-lsfg-vk'):
        copy(root / 'home/steamos/homebrew/plugins' / name, stage / 'home/steamos/homebrew/plugins' / name)
    (stage / 'boot').mkdir()
    subprocess.run(['cp', a.kernel, str(stage / 'boot/KERNEL')], check=True)
    files = {}
    for p in sorted(stage.rglob('*')):
        if not p.is_file() or p.is_symlink(): continue
        h = hashlib.sha256()
        with p.open('rb') as f:
            for b in iter(lambda: f.read(4 << 20), b''): h.update(b)
        files[str(p.relative_to(stage))] = h.hexdigest()
    (stage / 'manifest.json').write_text(json.dumps({'format': 1, 'architecture': 'aarch64',
        'devices': _updater.SOC_MODELS[a.soc], 'version': a.version, 'files': files}, indent=2))
    subprocess.run(['tar', '--xattrs', '--acls', '--numeric-owner', '-czf', str(output) + '.part',
                    '-C', str(stage), 'manifest.json', 'root', 'home', 'boot'], check=True)
    os.replace(str(output) + '.part', output)
h = hashlib.sha256()
with output.open('rb') as f:
    for b in iter(lambda: f.read(4 << 20), b''): h.update(b)
output.with_name(output.name + '.sha256').write_text(h.hexdigest() + '  ' + output.name + '\n')
print(output, h.hexdigest())
