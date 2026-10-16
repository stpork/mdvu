#!/usr/bin/env python3
"""
Generate custom WiX installer bitmaps (dialog.bmp and banner.bmp) matching the MDVu theme.
Zero external dependencies (uses standard library struct and zlib).
"""

import os
import struct
import zlib
import math

def decode_png(path):
    with open(path, "rb") as f:
        data = f.read()

    pos = 8
    width = height = 0
    idat = bytearray()
    while pos < len(data):
        length, chunk_type = struct.unpack(">I4s", data[pos:pos+8])
        pos += 8
        chunk_data = data[pos:pos+length]
        pos += length + 4
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk_data)
            if bit_depth != 8 or color_type != 6:
                raise ValueError(f"Unsupported PNG format: depth={bit_depth}, color_type={color_type}")
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)

    raw = zlib.decompress(bytes(idat))
    bpp = 4
    stride = width * bpp
    pixels = bytearray(width * height * 4)

    def paeth(a, b, c):
        p = a + b - c
        pa = abs(p - a)
        pb = abs(p - b)
        pc = abs(p - c)
        if pa <= pb and pa <= pc: return a
        if pb <= pc: return b
        return c

    raw_idx = 0
    for y in range(height):
        filter_type = raw[raw_idx]
        raw_idx += 1
        scanline = bytearray(raw[raw_idx:raw_idx+stride])
        raw_idx += stride
        prev_line = pixels[(y-1)*stride:y*stride] if y > 0 else bytearray(stride)
        curr_line = bytearray(stride)
        for x in range(stride):
            a = curr_line[x - bpp] if x >= bpp else 0
            b = prev_line[x]
            c = prev_line[x - bpp] if x >= bpp else 0
            val = scanline[x]
            if filter_type == 0: filt = val
            elif filter_type == 1: filt = (val + a) & 0xff
            elif filter_type == 2: filt = (val + b) & 0xff
            elif filter_type == 3: filt = (val + ((a + b) >> 1)) & 0xff
            elif filter_type == 4: filt = (val + paeth(a, b, c)) & 0xff
            curr_line[x] = filt
        pixels[y*stride:(y+1)*stride] = curr_line

    return width, height, pixels

def scale_rgba_bilinear(src_w, src_h, src_pixels, dst_w, dst_h):
    dst = bytearray(dst_w * dst_h * 4)
    for dy in range(dst_h):
        sy = (dy + 0.5) * src_h / dst_h - 0.5
        y0 = max(0, min(int(math.floor(sy)), src_h - 1))
        y1 = max(0, min(y0 + 1, src_h - 1))
        fy = sy - y0

        for dx in range(dst_w):
            sx = (dx + 0.5) * src_w / dst_w - 0.5
            x0 = max(0, min(int(math.floor(sx)), src_w - 1))
            x1 = max(0, min(x0 + 1, src_w - 1))
            fx = sx - x0

            w00 = (1.0 - fx) * (1.0 - fy)
            w10 = fx * (1.0 - fy)
            w01 = (1.0 - fx) * fy
            w11 = fx * fy

            i00 = (y0 * src_w + x0) * 4
            i10 = (y0 * src_w + x1) * 4
            i01 = (y1 * src_w + x0) * 4
            i11 = (y1 * src_w + x1) * 4

            dst_idx = (dy * dst_w + dx) * 4
            for c in range(4):
                val = (
                    src_pixels[i00 + c] * w00 +
                    src_pixels[i10 + c] * w10 +
                    src_pixels[i01 + c] * w01 +
                    src_pixels[i11 + c] * w11
                )
                dst[dst_idx + c] = max(0, min(255, int(round(val))))

    return dst

def write_bmp24(path, width, height, get_rgb_fn):
    """
    Write 24-bit uncompressed Windows BMP file.
    get_rgb_fn(x, y) returns (r, g, b) where (0, 0) is top-left.
    """
    row_bytes = width * 3
    padding = (4 - (row_bytes % 4)) % 4
    stride = row_bytes + padding
    image_size = stride * height
    file_size = 54 + image_size

    # BITMAPFILEHEADER (14 bytes)
    bmp_header = struct.pack(
        "<2sIHHI",
        b"BM",
        file_size,
        0, 0,
        54
    )

    # BITMAPINFOHEADER (40 bytes)
    dib_header = struct.pack(
        "<IIIHHIIIIII",
        40,          # biSize
        width,       # biWidth
        height,      # biHeight (positive = bottom-up)
        1,           # biPlanes
        24,          # biBitCount
        0,           # biCompression (BI_RGB)
        image_size,  # biSizeImage
        2835,        # biXPelsPerMeter (72 DPI)
        2835,        # biYPelsPerMeter
        0,           # biClrUsed
        0            # biClrImportant
    )

    rows = []
    # Bottom-up: row 0 in BMP file is the bottom-most row (y = height - 1)
    for y in reversed(range(height)):
        row = bytearray(stride)
        for x in range(width):
            r, g, b = get_rgb_fn(x, y)
            offset = x * 3
            row[offset] = b
            row[offset + 1] = g
            row[offset + 2] = r
        rows.append(row)

    with open(path, "wb") as f:
        f.write(bmp_header)
        f.write(dib_header)
        for row in rows:
            f.write(row)

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    icon_path = os.path.join(root, "packaging", "AppIcon-256.png")
    out_dir = os.path.join(root, "packaging", "windows")
    os.makedirs(out_dir, exist_ok=True)

    dialog_bmp = os.path.join(out_dir, "dialog.bmp")
    banner_bmp = os.path.join(out_dir, "banner.bmp")

    print(f"Decoding {icon_path}...")
    src_w, src_h, src_pixels = decode_png(icon_path)

    # 1. Generate dialog.bmp (493 x 312)
    # Left banner is 164 px wide. Right 329 px is pure white.
    dialog_w, dialog_h = 493, 312
    left_banner_w = 164
    icon_dialog_size = 108
    icon_dialog = scale_rgba_bilinear(src_w, src_h, src_pixels, icon_dialog_size, icon_dialog_size)

    # Icon top-left position inside left banner:
    icon_dialog_x = (left_banner_w - icon_dialog_size) // 2
    icon_dialog_y = 62

    def dialog_pixel(x, y):
        if x > left_banner_w:
            return (255, 255, 255) # Pure white for installer text
        elif x == left_banner_w:
            return (218, 224, 233) # 1px subtle divider line

        # Gradient for left banner: Dark Slate Navy -> Deep Indigo
        t = y / float(dialog_h)
        # Top: #17223b (23, 34, 59) -> Bottom: #0c1222 (12, 18, 34)
        bg_r = int(23 * (1.0 - t) + 12 * t)
        bg_g = int(34 * (1.0 - t) + 18 * t)
        bg_b = int(59 * (1.0 - t) + 34 * t)

        # Subtle decorative accent circle or wave in background
        dx = x - 82
        dy = y - 116
        dist = math.sqrt(dx*dx + dy*dy)
        if 64 < dist < 82:
            glow = math.sin((dist - 64) / 18.0 * math.pi) * 0.15
            bg_r = min(255, int(bg_r + glow * 50))
            bg_g = min(255, int(bg_g + glow * 90))
            bg_b = min(255, int(bg_b + glow * 160))

        # Check if inside icon area
        ix = x - icon_dialog_x
        iy = y - icon_dialog_y

        # Drop shadow around icon
        if -4 <= ix < icon_dialog_size + 4 and -2 <= iy < icon_dialog_size + 6:
            # Simple shadow blur
            shadow_dist = max(0, min(abs(ix - icon_dialog_size//2), abs(iy - icon_dialog_size//2)))
            bg_r = int(bg_r * 0.88)
            bg_g = int(bg_g * 0.88)
            bg_b = int(bg_b * 0.88)

        if 0 <= ix < icon_dialog_size and 0 <= iy < icon_dialog_size:
            idx = (iy * icon_dialog_size + ix) * 4
            ir = icon_dialog[idx]
            ig = icon_dialog[idx + 1]
            ib = icon_dialog[idx + 2]
            alpha = icon_dialog[idx + 3] / 255.0
            out_r = int(ir * alpha + bg_r * (1.0 - alpha))
            out_g = int(ig * alpha + bg_g * (1.0 - alpha))
            out_b = int(ib * alpha + bg_b * (1.0 - alpha))
            return (out_r, out_g, out_b)

        return (bg_r, bg_g, bg_b)

    print(f"Generating {dialog_bmp} ({dialog_w}x{dialog_h})...")
    write_bmp24(dialog_bmp, dialog_w, dialog_h, dialog_pixel)

    # 2. Generate banner.bmp (493 x 58)
    banner_w, banner_h = 493, 58
    icon_banner_size = 46
    icon_banner = scale_rgba_bilinear(src_w, src_h, src_pixels, icon_banner_size, icon_banner_size)
    icon_banner_x = banner_w - icon_banner_size - 16
    icon_banner_y = (banner_h - icon_banner_size) // 2

    def banner_pixel(x, y):
        # 1px bottom border
        if y == banner_h - 1:
            return (226, 232, 240)

        bg_r, bg_g, bg_b = 255, 255, 255

        # Check icon area on the right
        ix = x - icon_banner_x
        iy = y - icon_banner_y
        if 0 <= ix < icon_banner_size and 0 <= iy < icon_banner_size:
            idx = (iy * icon_banner_size + ix) * 4
            ir = icon_banner[idx]
            ig = icon_banner[idx + 1]
            ib = icon_banner[idx + 2]
            alpha = icon_banner[idx + 3] / 255.0
            out_r = int(ir * alpha + bg_r * (1.0 - alpha))
            out_g = int(ig * alpha + bg_g * (1.0 - alpha))
            out_b = int(ib * alpha + bg_b * (1.0 - alpha))
            return (out_r, out_g, out_b)

        return (bg_r, bg_g, bg_b)

    print(f"Generating {banner_bmp} ({banner_w}x{banner_h})...")
    write_bmp24(banner_bmp, banner_w, banner_h, banner_pixel)
    print("Done! WiX bitmaps generated successfully.")

if __name__ == "__main__":
    main()
