#!/usr/bin/env python3
"""
Constant-pool class-file relocator (mini maven-shade).

Rewrites package references in .class files by editing CONSTANT_Utf8 entries:
  - whole-string internal class names   (io/github/bakedlibs/dough/Foo)
  - descriptor segments                 (Lio/github/bakedlibs/dough/Foo;)
  - signature-embedded segments         (Ljava/util/List<Lio/.../Foo;>;)

This mirrors what maven-shade's ASM ClassRemapper does for names, descriptors
and Signature attributes (string literals are intentionally left untouched,
matching shade's default behaviour).

Usage:
  relocate.py <in.jar-or-dir> <out.jar-or-dir> <old1>=<new1> [<old2>=<new2> ...]
  (mappings given in internal form with slashes, e.g. io/github/bakedlibs/dough=io/github/thebusybiscuit/slimefun4/libraries/dough)
"""
import io
import struct
import sys
import zipfile
from pathlib import Path

CONSTANT_Utf8 = 1
CONSTANT_Integer = 3
CONSTANT_Float = 4
CONSTANT_Long = 5
CONSTANT_Double = 6
CONSTANT_Class = 7
CONSTANT_String = 8
CONSTANT_Fieldref = 9
CONSTANT_Methodref = 10
CONSTANT_InterfaceMethodref = 11
CONSTANT_NameAndType = 12
CONSTANT_MethodHandle = 15
CONSTANT_MethodType = 16
CONSTANT_Dynamic = 17
CONSTANT_InvokeDynamic = 18
CONSTANT_Module = 19
CONSTANT_Package = 20

# sizes of the extra bytes each constant type carries (after the 1-byte tag)
EXTRA = {
    CONSTANT_Utf8: None,  # variable
    CONSTANT_Integer: 4,
    CONSTANT_Float: 4,
    CONSTANT_Long: 8,
    CONSTANT_Double: 8,
    CONSTANT_Class: 2,
    CONSTANT_String: 2,
    CONSTANT_Fieldref: 4,
    CONSTANT_Methodref: 4,
    CONSTANT_InterfaceMethodref: 4,
    CONSTANT_NameAndType: 4,
    CONSTANT_MethodHandle: 3,
    CONSTANT_MethodType: 2,
    CONSTANT_Dynamic: 4,
    CONSTANT_InvokeDynamic: 4,
    CONSTANT_Module: 2,
    CONSTANT_Package: 2,
}


def parse_pool(data: bytes):
    """Return (list of (tag, value-or-None), rest-of-file bytes)."""
    if data[4:8] != b"\xca\xfe\xba\xbe"[0:0] + b"":
        pass
    magic = data[0:4]
    assert magic == b"\xca\xfe\xba\xbe", "not a class file"
    minor, major = struct.unpack(">HH", data[4:8])
    count = struct.unpack(">H", data[8:10])[0]
    pos = 10
    entries = []  # 1-indexed conceptually; entries[0] is dummy
    i = 1
    while i < count:
        tag = data[pos]
        pos += 1
        if tag == CONSTANT_Utf8:
            ln = struct.unpack(">H", data[pos:pos + 2])[0]
            pos += 2
            val = data[pos:pos + ln]
            pos += ln
            entries.append((tag, val))
        else:
            size = EXTRA[tag]
            entries.append((tag, data[pos:pos + size]))
            pos += size
            if tag in (CONSTANT_Long, CONSTANT_Double):
                entries.append((0, None))  # takes two slots
                i += 1
        i += 1
    return entries, data[pos:], (minor, major)


def rewrite_utf8(val: bytes, mappings) -> bytes:
    """Rewrite class-name-like content in a UTF8 constant."""
    try:
        s = val.decode("utf-8")
    except UnicodeDecodeError:
        return val

    out = s
    for old, new in mappings:
        # 1) whole string is an internal class name (or package name)
        if out == old or out.startswith(old + "/"):
            # only rewrite if the remainder looks like a class path (no ; < ( )
            rest = out[len(old):]
            if not any(c in rest for c in ";<>()"):
                out = new + rest
                continue
        # 2) descriptor / signature segments: L<old>...;
        if "L" + old in out:
            out = out.replace("L" + old, "L" + new)
    return out.encode("utf-8")


def relocate_class(data: bytes, mappings) -> bytes:
    entries, rest, (minor, major) = parse_pool(data)
    out = io.BytesIO()
    out.write(b"\xca\xfe\xba\xbe")
    out.write(struct.pack(">HH", minor, major))
    out.write(struct.pack(">H", len(entries) + 1))
    for tag, val in entries:
        if tag == 0:
            continue  # phantom slot of long/double (never first)
        out.write(bytes([tag]))
        if tag == CONSTANT_Utf8:
            new_val = rewrite_utf8(val, mappings)
            out.write(struct.pack(">H", len(new_val)))
            out.write(new_val)
        else:
            out.write(val)
    out.write(rest)
    return out.getvalue()


def main():
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    mappings = []
    for m in sys.argv[3:]:
        old, new = m.split("=")
        mappings.append((old, new))

    if src.is_file() and src.suffix == ".jar":
        dst.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename.endswith(".class") and item.filename != "module-info.class":
                    data = relocate_class(data, mappings)
                zi = zipfile.ZipInfo(item.filename, date_time=item.date_time)
                zi.compress_type = zipfile.ZIP_DEFLATED
                zout.writestr(zi, data)
    else:
        # directory tree in/out
        for f in sorted(src.rglob("*.class")):
            data = f.read_bytes()
            new = relocate_class(data, mappings)
            rel = f.relative_to(src)
            target = dst / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(new)
    print(f"relocate: {src} -> {dst} with {len(mappings)} mapping(s)")


if __name__ == "__main__":
    main()
