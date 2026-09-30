#!/usr/bin/env python3
"""
Relocation audit for the assembled Slimefun jar.

Asserts that no class in the jar references the un-relocated package names of
the shaded libraries (dough / paperlib / commons-lang), mirroring what the
maven-shade-plugin's relocation rules guarantee in the official build.

Usage: audit.py <jar>
"""
import re
import struct
import sys
import zipfile

BAD_PATTERNS = [
    b'io/github/bakedlibs',
    re.compile(rb'io/papermc/lib(?!rar)'),
    re.compile(rb'org/apache/commons/lang(?!3)'),
]


def utf8_constants(data):
    pos = 10
    entries = []
    count = struct.unpack('>H', data[8:10])[0]
    i = 1
    while i < count:
        tag = data[pos]; pos += 1
        if tag == 1:
            ln = struct.unpack('>H', data[pos:pos + 2])[0]; pos += 2
            entries.append(data[pos:pos + ln]); pos += ln
        else:
            sizes = {3: 4, 4: 4, 5: 8, 6: 8, 7: 2, 8: 2, 9: 4, 10: 4, 11: 4, 12: 4, 15: 3, 16: 2, 17: 4, 18: 4, 19: 2, 20: 2}
            pos += sizes[tag]
            if tag in (5, 6):
                entries.append(None); i += 1
        i += 1
    return entries


def main(jar_path):
    jar = zipfile.ZipFile(jar_path)
    checked = bad = 0
    for name in jar.namelist():
        if not name.endswith('.class'):
            continue
        checked += 1
        for c in utf8_constants(jar.read(name)):
            if c is None:
                continue
            for pat in BAD_PATTERNS:
                if (pat.search(c) if hasattr(pat, 'search') else pat in c):
                    bad += 1
                    print(f"BAD: {name} -> {c[:120]!r}")
                    break
    print(f"audit: checked {checked} classes, unrelocated references: {bad}")
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main(sys.argv[1])
