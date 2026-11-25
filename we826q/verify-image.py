#!/usr/bin/env python3
"""Fail closed: TP-Link V1 + fwtool trailer, SquashFS and eraseblock budget."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib

LIMIT = 0xF80000
BLOCK = 0x10000
MIN_OVERLAY = 0x80000
SALT = bytes.fromhex('dcd73aa5c39598fbddf9e7f40eae4738')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def verify(image, manifest):
    raw = Path(image).read_bytes()
    require(512 < len(raw) <= LIMIT, 'image must be <= 0xf80000')
    data = raw
    # append-metadata uses fwtool: payload followed by a 16-byte BE trailer.
    while len(data) >= 16 and data[-16:-12] == b'FWx0':
        magic, crc, kind, size = struct.unpack('>4sIII', data[-16:])
        require(16 <= size <= len(data) - 512, 'invalid fwtool size')
        # fwtool CRC is its running CRC32 (no final XOR).
        require((zlib.crc32(data[:-16]) ^ 0xFFFFFFFF) == crc,
                'fwtool CRC32 mismatch')
        data = data[:-size]
    require(data[:4] == b'\x01\x00\x00\x00', 'not TP-Link V1')
    u32 = lambda off: struct.unpack_from('>I', data, off)[0]
    require(u32(64) == 0 and u32(68) == 1, 'unexpected HWID/revision')
    fwlen, koff, klen, roff, rlen, boff, blen = struct.unpack_from('>7I', data, 124)
    require(koff == 512, 'TP-Link header must be 512 bytes')
    require(fwlen == LIMIT and boff == 0 and blen == 0, 'invalid layout or bootloader payload')
    require(klen > 0 and koff + klen <= roff, 'kernel overlaps rootfs')
    require(roff + rlen <= len(data), 'truncated rootfs')
    salted = bytearray(data)
    expected = bytes(salted[76:92])
    salted[76:92] = SALT
    require(hashlib.md5(salted).digest() == expected, 'TP-Link salted MD5 mismatch')
    require(data[roff:roff + 4] == b'hsqs', 'SquashFS magic absent at header rootfs offset')
    require(struct.unpack_from('<H', data, roff + 28)[0] == 4, 'not SquashFS v4')
    used = struct.unpack_from('<Q', data, roff + 40)[0]
    require(96 <= used <= rlen and roff + used <= len(data), 'invalid SquashFS bytes_used')
    overlay_start = (roff + used + BLOCK - 1) // BLOCK * BLOCK
    # Use the smaller TP-Link cap, rather than the larger physical partition.
    overlay = LIMIT - overlay_start
    require(overlay >= MIN_OVERLAY, 'less than 512 KiB eraseblock-aligned overlay')
    packages = {line.split()[0] for line in Path(manifest).read_text().splitlines() if line.strip()}
    require({'frpc', 'we826q-tailscale'} <= packages, 'required packages absent from manifest')
    return dict(status='EXPERIMENTAL NOT FLASHED', image_bytes=len(raw),
                tplink_bytes=len(data), squashfs_bytes_used=used,
                overlay_start=overlay_start, overlay_bytes=overlay,
                sha256=hashlib.sha256(raw).hexdigest())


if __name__ == '__main__':
    try:
        print(json.dumps(verify(*sys.argv[1:]), indent=2))
    except (ValueError, OSError, struct.error, TypeError) as exc:
        sys.exit(f'REJECTED: {exc}')
