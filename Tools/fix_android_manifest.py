"""Fix Godot 4.6.3 template export's duplicate provider authorities.

Usage: python Tools/fix_android_manifest.py exported.apk unsigned-fixed.apk
After this step, zipalign and sign the output. APK signatures are invalidated.
The template exporter rewrites every provider authority to '.fileprovider'.
Keep FileProvider as-is and give AndroidX startup its own unique authority.
"""
import struct
import sys
import zipfile
from pathlib import Path


def fix_manifest(data):
    blob = bytearray(data)
    strings, locations = [], []
    offset = 8
    changes = 0
    while offset < len(blob):
        kind, header, size = struct.unpack_from('<HHI', blob, offset)
        if size < 8:
            raise ValueError('Invalid Android XML chunk')
        if kind == 0x0001:
            count, _, flags, start, _ = struct.unpack_from('<IIIII', blob, offset + 8)
            utf8 = bool(flags & 0x100)
            for i in range(count):
                relative = struct.unpack_from('<I', blob, offset + header + i * 4)[0]
                at = offset + start + relative
                if utf8:
                    # Skip UTF-16 character count, then read UTF-8 byte length.
                    at += 2 if blob[at] & 0x80 else 1
                    length = blob[at]
                    at += 1
                    if length & 0x80:
                        length = ((length & 0x7f) << 8) | blob[at]
                        at += 1
                    encoding = 'utf-8'
                else:
                    length = struct.unpack_from('<H', blob, at)[0]
                    at += 2
                    if length & 0x8000:
                        length = ((length & 0x7fff) << 16) | struct.unpack_from('<H', blob, at)[0]
                        at += 2
                    length *= 2
                    encoding = 'utf-16le'
                strings.append(bytes(blob[at:at + length]).decode(encoding))
                locations.append((at, length, encoding))
        elif kind == 0x0102:
            name = struct.unpack_from('<I', blob, offset + 20)[0]
            if strings[name] == 'provider':
                attr_start, attr_size, attr_count = struct.unpack_from('<HHH', blob, offset + 24)
                attributes = {}
                for i in range(attr_count):
                    at = offset + 16 + attr_start + i * attr_size
                    _, attr_name, _, _, _, value_type, value = struct.unpack_from('<IIIHBBI', blob, at)
                    if value_type == 3:
                        attributes[strings[attr_name]] = value
                provider = strings[attributes['name']]
                authority = strings[attributes['authorities']]
                if provider == 'androidx.startup.InitializationProvider' and authority.endswith('.fileprovider'):
                    replacement = authority[:-len('.fileprovider')] + '.initprovider'
                    at, length, encoding = locations[attributes['authorities']]
                    encoded = replacement.encode(encoding)
                    if len(encoded) != length:
                        raise ValueError('Provider replacement must preserve string-pool offsets')
                    blob[at:at + length] = encoded
                    changes += 1
        offset += size
    return bytes(blob), changes


def main():
    source, destination = map(Path, sys.argv[1:3])
    if source.resolve() == destination.resolve():
        raise ValueError('Use a separate output path')
    with zipfile.ZipFile(source) as zin, zipfile.ZipFile(destination, 'w') as zout:
        modified, changes = fix_manifest(zin.read('AndroidManifest.xml'))
        for entry in zin.infolist():
            if entry.filename.startswith('META-INF/') and entry.filename.upper().endswith(('.SF', '.RSA', '.DSA', '.EC', 'MANIFEST.MF')):
                continue
            contents = modified if entry.filename == 'AndroidManifest.xml' else zin.read(entry.filename)
            zout.writestr(entry, contents)
    print(f'AndroidX provider authority corrections: {changes}')


if __name__ == '__main__':
    main()
