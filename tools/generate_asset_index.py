"""Writes Assets/index.json, the list of real file names in Assets/.

The game uses it to resolve asset names case-insensitively, since web servers
(e.g. GitHub Pages) are case-sensitive while Windows is not.
Run after adding, removing or renaming files in Assets/.
"""
import json
import os

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Assets')
names = sorted(n for n in os.listdir(root)
               if os.path.isfile(os.path.join(root, n)) and n != 'index.json')
with open(os.path.join(root, 'index.json'), 'w', encoding='utf-8') as f:
    json.dump(names, f, indent=0)
print(f'Wrote {len(names)} entries')
