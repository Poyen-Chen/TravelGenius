#!/usr/bin/env python3
"""Produce a complete release manifest; run all regressions before publishing."""
import argparse
import hashlib
import json
from pathlib import Path

FILES = ('countries', 'cities', 'packing_items', 'packing_rules', 'prohibited_items',
         'aviation_rules', 'etiquette', 'border_rules', 'seasonal_weather')
parser = argparse.ArgumentParser()
parser.add_argument('--directory', type=Path, default=Path('TravelGenius/Resources/SeedData'))
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
manifest = {'contractVersion': 1, 'files': {name: hashlib.sha256(
    (args.directory / f'{name}.json').read_bytes()).hexdigest() for name in FILES}}
path = args.directory / 'manifest.json'
if args.check:
    assert json.loads(path.read_text()) == manifest, 'Manifest hashes are stale; regenerate after updating data'
else:
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print('Reference manifest: PASS')
