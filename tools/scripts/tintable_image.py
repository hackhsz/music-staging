"""Turn coloured UI art into a tintable base: `grey` keeps the shading, `white` keeps only the alpha.

    python tools/scripts/tintable_image.py grey in.png out.png
    python tools/scripts/tintable_image.py white in.png out.png

Standard library only. Reads 8-bit, non-interlaced PNGs.
"""
import struct
import sys
import zlib

def read(path):
    data = open(path, "rb").read()
    pos = 8; idat = b""; w = h = ct = None
    while pos < len(data):
        ln, = struct.unpack(">I", data[pos:pos+4]); typ = data[pos+4:pos+8]; body = data[pos+8:pos+8+ln]; pos += 12 + ln
        if typ == b"IHDR": w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", body); assert bd == 8 and il == 0, (bd, il)
        elif typ == b"IDAT": idat += body
        elif typ == b"IEND": break
    bpp = {6: 4, 2: 3, 0: 1, 4: 2}[ct]
    raw = zlib.decompress(idat); stride = w * bpp; out = bytearray(); prev = bytearray(stride); i = 0
    for _ in range(h):
        f = raw[i]; line = bytearray(raw[i+1:i+1+stride]); i += 1 + stride
        for x in range(stride):
            a = line[x-bpp] if x >= bpp else 0; b = prev[x]; c = prev[x-bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c; pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += line; prev = line
    if bpp != 4:
        rgba = bytearray()
        for k in range(w*h):
            px = out[k*bpp:(k+1)*bpp]
            if bpp == 3: rgba += px + b"\xff"
            elif bpp == 1: rgba += bytes([px[0]]*3) + b"\xff"
            else: rgba += bytes([px[0]]*3) + bytes([px[1]])
        out = rgba
    return w, h, out
def write(path, w, h, rgba):
    raw = b"".join(b"\x00" + bytes(rgba[y*w*4:(y+1)*w*4]) for y in range(h))
    def chunk(t, b): return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


# The 90th-percentile brightness maps to white so ImageColor3 shows its full colour; the curve lifts mid-tones.
def grey(w, h, px):
    def lum(i):
        return 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]

    lums = sorted(lum(k * 4) for k in range(w * h) if px[k * 4 + 3] > 200)
    hi = lums[max(0, int(len(lums) * 0.9) - 1)] or 1
    for k in range(w * h):
        i = k * 4
        px[i] = px[i + 1] = px[i + 2] = int(min(max(lum(i) / hi, 0), 1) ** 0.6 * 255)


def white(w, h, px):
    for k in range(w * h):
        px[k * 4] = px[k * 4 + 1] = px[k * 4 + 2] = 255


if __name__ == "__main__":
    mode, src, dst = sys.argv[1:4]
    w, h, px = read(src)
    {"grey": grey, "white": white}[mode](w, h, px)
    write(dst, w, h, px)
