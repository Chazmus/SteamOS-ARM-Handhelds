#!/usr/bin/env python3
"""Build a format 2 update: signed, content-addressed, full or delta.

  build-update-v2.py --rootfs R --kernel KERNEL --soc sm8650 --version 1.3.0 \
      --sign-key ~/.config/steamos-arm-release/update-signing.pem \
      --output steamos-arm-sm8650-1.3.0.sau [--from 1.2.9.inventory.json ...]

Without --from it is a full package (every file's contents). With --from it
is a delta that installs on any of those releases and carries only contents
none of them had. Next to the package it writes <output>.inventory.json,
what a later release's delta is built --from, and <output>.sha256.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    'konkr_update', Path(__file__).resolve().parent.parent / 'external-and-mods/konkr-update/konkr-update.py')
U = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(U)

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument('--rootfs', required=True)
ap.add_argument('--kernel', required=True)
ap.add_argument('--soc', default='sm8650', choices=sorted(U.SOC_MODELS))
ap.add_argument('--version', required=True)
ap.add_argument('--output', required=True)
ap.add_argument('--sign-key', required=True, help='Ed25519 private key (PEM)')
ap.add_argument('--from', dest='bases', action='append', default=[],
                help='inventory of a release this delta installs on (repeatable)')
a = ap.parse_args()

root = Path(a.rootfs).resolve()
output = Path(a.output).resolve()
if not (root / 'usr/lib/liblsfg-vk-layer-arm64.so').is_file():
    raise SystemExit('missing LSFG v2 ARM layer')


def base_of(prefix):
    return root / prefix.split('/', 1)[1] if prefix.startswith('root/') else root / prefix


inventory = U.walk_managed(base_of, skip_etc=True)
inventory.pop('root/' + U.INVENTORY, None)          # rewritten by the device itself
inventory['boot/KERNEL'] = U.entry_for(a.kernel)
inventory['boot/KERNEL']['f'][:3] = [0o755, 0, 0]

source = {}                                         # sha -> a file with that content
for key, e in inventory.items():
    if 'f' in e:
        source.setdefault(e['f'][4], a.kernel if key == 'boot/KERNEL' else base_of(key))

have, versions = set(), []
for b in a.bases:
    base = json.loads(Path(b).read_text())
    versions.append(base['version'])
    if 'inventory' in base:                         # <package>.inventory.json
        have |= {e['f'][4] for e in base['inventory'].values() if 'f' in e}
    else:                                           # a release's installed.json
        have |= {v[2] for v in base['files'].values()}
blobs = sorted(set(source) - have)

with tempfile.TemporaryDirectory(prefix='sau-', dir=output.parent) as temp:
    stage = Path(temp)
    for sha in blobs:
        dst = stage / 'blobs' / sha[:2] / sha
        dst.parent.mkdir(parents=True, exist_ok=True)
        src = Path(source[sha])
        try:
            os.link(src, dst)
        except OSError:
            shutil.copyfile(src, dst)
    manifest = {
        'format': U.FORMAT2, 'architecture': 'aarch64', 'version': a.version,
        'devices': U.SOC_MODELS[a.soc], 'kind': 'delta' if versions else 'full',
        'from': versions, 'blobs': blobs, 'inventory': inventory,
    }
    (stage / 'manifest.json').write_text(json.dumps(manifest, separators=(',', ':'), sort_keys=True))
    U.sign_manifest(stage / 'manifest.json', Path(a.sign_key).expanduser(), stage / 'manifest.sig')
    members = ['manifest.json', 'manifest.sig'] + (['blobs'] if blobs else [])
    subprocess.run(['tar', '--numeric-owner', '--owner=0', '--group=0', '-czf', str(output) + '.part',
                    '-C', str(stage), *members], check=True)
    os.replace(str(output) + '.part', output)

output.with_name(output.name + '.inventory.json').write_text(
    json.dumps({'version': a.version, 'inventory': inventory}, separators=(',', ':')))
h = hashlib.sha256()
with output.open('rb') as f:
    for chunk in iter(lambda: f.read(4 << 20), b''):
        h.update(chunk)
output.with_name(output.name + '.sha256').write_text(h.hexdigest() + '  ' + output.name + '\n')
size = sum(os.path.getsize(source[s]) for s in blobs)
print(f"{output}: {manifest['kind']} {a.version}, {len(inventory)} paths, "
      f"{len(blobs)} blobs ({size / 1e6:.0f} MB before compression), sha256 {h.hexdigest()}")
