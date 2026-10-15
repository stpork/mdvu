#!/usr/bin/env python3
import os
import subprocess
import time
import json
import statistics

FIXTURES = [
    ("README.md", "README.md"),
    ("test-heavy.md", "Tests/Fixtures/test-heavy.md"),
    ("test-complete.md", "Tests/Fixtures/test-complete.md"),
]

def measure_file_size(path):
    if os.path.exists(path):
        return os.path.getsize(path)
    return None

def run_cli_bench(bin_path, fixture_path, iterations=50):
    with open(fixture_path, "rb") as f:
        data = f.read()
    size_bytes = len(data)
    size_mb = size_bytes / (1024 * 1024)

    durations = []
    # Warmup
    for _ in range(5):
        subprocess.run([bin_path, fixture_path, "-o", "/dev/null"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    for _ in range(iterations):
        t0 = time.perf_counter()
        subprocess.run([bin_path, fixture_path, "-o", "/dev/null"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        t1 = time.perf_counter()
        durations.append(t1 - t0)

    median_duration = statistics.median(durations)
    mean_duration = statistics.mean(durations)
    stdev_duration = statistics.stdev(durations) if len(durations) > 1 else 0
    throughput_mb_s = size_mb / median_duration if median_duration > 0 else 0

    return {
        "file": os.path.basename(fixture_path),
        "size_kb": size_bytes / 1024,
        "median_ms": median_duration * 1000,
        "mean_ms": mean_duration * 1000,
        "stdev_ms": stdev_duration * 1000,
        "throughput_mb_s": throughput_mb_s,
    }

def main():
    print("=== MDVu Performance & Size Benchmarking ===")
    
    # 1. Binary Sizes
    print("\n--- 1. Binary & Bundle Sizes ---")
    binaries = [
        ("Swift macOS binary", ".build/release/mdvu"),
        ("Swift macOS app bundle", "dist/mdvu.app"),
        ("Rust Core static library", "target/release/libmdvu_core.a"),
        ("Rust Core dylib", "target/release/libmdvu_core.dylib"),
        ("Rust CLI binary", "target/release/mdvu-cli"),
        ("Rust Windows binary (host/simulated)", "target/release/mdvu-windows"),
    ]
    
    for name, path in binaries:
        if os.path.isdir(path):
            total_size = sum(os.path.getsize(os.path.join(dirpath, f)) for dirpath, _, filenames in os.walk(path) for f in filenames)
            print(f"  {name:35}: {total_size / (1024*1024):.2f} MB ({total_size:,} bytes)")
        elif os.path.exists(path):
            sz = os.path.getsize(path)
            print(f"  {name:35}: {sz / (1024*1024):.2f} MB ({sz:,} bytes)")
        else:
            print(f"  {name:35}: Not found at {path}")

    # 2. Embedded Assets Breakdown
    print("\n--- 2. Compressed Assets Breakdown (Embedded in mdvu-core & mdvu) ---")
    assets = [
        ("Mermaid 11.17.2 + ZenUML (mermaid.lzma)", "Sources/mdvu/Resources/mermaid.lzma"),
        ("PlantUML 1.2026.7 + Viz.js (plantuml.lzma)", "Sources/mdvu/Resources/plantuml.lzma"),
        ("KaTeX MathML Engine (katex.lzma)", "Sources/mdvu/Resources/katex.lzma"),
        ("Markdown Stylesheet (markdown.css)", "Sources/mdvu/Resources/markdown.css"),
        ("App Runtime Script (app.js)", "Sources/mdvu/Resources/app.js"),
    ]
    total_assets = 0
    for name, path in assets:
        if os.path.exists(path):
            sz = os.path.getsize(path)
            total_assets += sz
            print(f"  {name:42}: {sz / 1024:.1f} KB ({sz:,} bytes)")
    print(f"  {'Total Embedded Assets':42}: {total_assets / (1024*1024):.2f} MB ({total_assets:,} bytes)")

    # 3. Rust CLI Performance Benchmark
    print("\n--- 3. Rust mdvu-core Throughput Benchmark (via mdvu-cli) ---")
    cli_bin = "target/release/mdvu-cli"
    if os.path.exists(cli_bin):
        for label, fpath in FIXTURES:
            if os.path.exists(fpath):
                res = run_cli_bench(cli_bin, fpath, iterations=30)
                print(f"  Fixture: {res['file']:25} | Size: {res['size_kb']:6.1f} KB | Time: {res['median_ms']:6.2f} ms | Throughput: {res['throughput_mb_s']:6.2f} MiB/s")

if __name__ == "__main__":
    main()
