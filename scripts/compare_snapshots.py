#!/usr/bin/env python3
import math
import sys
from PIL import Image, ImageChops, ImageStat

reference = Image.open(sys.argv[1]).convert("RGB")
actual = Image.open(sys.argv[2]).convert("RGB")
tolerance = 0.05  # Account for macOS vibrancy, window focus state, and text rasterization variances.
if reference.size != actual.size:
    rw, rh = reference.size
    aw, ah = actual.size
    if rw * ah != aw * rh or max(rw, aw) % min(rw, aw) or max(rh, ah) % min(rh, ah):
        raise SystemExit(f"snapshot size changed: {reference.size} != {actual.size}")
    target = (min(rw, aw), min(rh, ah))
    reference = reference.resize(target, Image.Resampling.LANCZOS)
    actual = actual.resize(target, Image.Resampling.LANCZOS)
    tolerance = 0.03  # Account for macOS 1x/2x text rasterization differences.

statistics = ImageStat.Stat(ImageChops.difference(reference, actual))
rms = math.sqrt(sum(value * value for value in statistics.rms) / len(statistics.rms)) / 255
print(f"snapshot normalized RMS difference: {rms:.5f}")
if rms > tolerance:
    raise SystemExit("visual regression exceeded tolerance")
