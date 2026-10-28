#!/usr/bin/env python3
"""Collect CPU, GPU, Memory, and Storage stats.

Vendored from the "dizziee.system-stats" Omarchy plugin
(https://github.com/JJDizz1L/dizziee.system-stats), MIT License,
Copyright (c) 2026 Dizziee. Used unmodified as the data source for
this bar's combined system-stats widget.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
from typing import Any


def read_int(path: str) -> int | None:
    try:
        with open(path) as f:
            return int(f.read().strip())
    except Exception:
        return None


def read_float(path: str) -> float | None:
    try:
        with open(path) as f:
            return float(f.read().strip())
    except Exception:
        return None


# ---------------------------------------------------------------- CPU

def cpu_name() -> str:
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line:
                    name = line.split(":")[1].strip()
                    name = re.sub(r"\d+-Core Processor.*", "", name).strip()
                    return name
    except Exception:
        pass
    return "CPU"


def read_str(path: str, default: str = "") -> str:
    try:
        with open(path) as f:
            return f.read().strip()
    except Exception:
        return default


def cpu_temp() -> int:
    for pattern in ["/sys/class/hwmon/hwmon*/temp*_input"]:
        for p in sorted(glob.glob(pattern)):
            label_file = p.replace("_input", "_label")
            label = read_str(label_file, "")
            if any(x in label.lower() for x in ["tdie", "tccd1", "package id 0", "tctl", "core 0"]):
                val = read_int(p)
                if val is not None:
                    return val // 1000
    for pattern in ["/sys/class/hwmon/hwmon*/temp*_input"]:
        for p in sorted(glob.glob(pattern)):
            label_file = p.replace("_input", "_label")
            label = read_str(label_file, "")
            if label and "ambient" not in label.lower() and "gpu" not in label.lower():
                val = read_int(p)
                if val is not None:
                    return val // 1000
    return 0


def cpu_freq() -> float:
    freqs: list[float] = []
    for f in glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"):
        val = read_float(f)
        if val is not None:
            freqs.append(val)
    if freqs:
        return round(sum(freqs) / len(freqs) / 1_000_000, 2)
    return 0.0


def cpu_power() -> float:
    for name_filter in ["k10temp", "zenpower", "coretemp"]:
        for h in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
            if read_str(h + "/name") == name_filter:
                for p in sorted(glob.glob(h + "/power*_input")):
                    val = read_int(p)
                    if val is not None:
                        return round(val / 1_000_000, 1)
                for p in sorted(glob.glob(h + "/power*_average")):
                    val = read_int(p)
                    if val is not None:
                        return round(val / 1_000_000, 1)
    return 0.0


def cpu_topology() -> dict[str, int]:
    cores = 0
    threads = 0
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("cpu cores"):
                    cores = int(line.split(":")[1].strip())
                elif line.startswith("processor"):
                    threads += 1
    except Exception:
        pass
    return {"cores": cores, "threads": threads}


# RAM type/speed detection ported from the "im0001gt.hw-tooltip" Omarchy
# plugin (https://github.com/IM0001GT/omarchy-hw-tooltip), MIT License,
# Copyright (c) 2026 IM0001GT. Adapted from its scripts/system-usage
# (dmidecode/inxi parsing only; BC-250-specific handling dropped as N/A here).

JUNK_RAM_TYPES = {
    "unknown", "other", "none", "no", "not", "empty", "uninstalled",
    "n/a", "n", "na", "ram", "dimm",
}


def clean_ram_types(types: list[str]) -> list[str]:
    return [t for t in types if t and t.lower() not in JUNK_RAM_TYPES]


def ram_from_dmidecode(text: str) -> tuple[list[str], list[str], list[str]]:
    types: list[str] = []
    speeds: list[str] = []
    parts: list[str] = []
    block: dict[str, str] = {}

    def flush():
        if not block:
            return
        size = block.get("Size", "")
        if not size or size == "No Module Installed":
            return
        types.extend(clean_ram_types([block.get("Type", "")]))
        speed = block.get("Configured Memory Speed") or block.get("Configured Clock Speed") or block.get("Speed")
        if speed:
            m = re.search(r"(\d+)\s*MT/s", speed)
            if m:
                speeds.append(m.group(1))
        part = block.get("Part Number", "")
        if part and part not in ("Unknown", "Not Specified", "NO DIMM", "N/A"):
            parts.append(part.strip())

    for line in text.splitlines():
        if not line.strip():
            flush()
            block = {}
            continue
        if ":" in line:
            k, v = line.split(":", 1)
            block[k.strip()] = v.strip()
    flush()
    return types, speeds, parts


def ram_from_inxi(text: str) -> tuple[list[str], list[str], list[str]]:
    types: list[str] = []
    speeds: list[str] = []
    for chunk in re.split(r"\s*Device-\d+:", text)[1:]:
        if re.search(r"\bno module installed\b|\bnot installed\b|\bno dimm\b", chunk, re.I):
            continue
        types.extend(clean_ram_types(re.findall(r"\btype:\s*([A-Za-z0-9/+-]+)", chunk)))
        actuals = re.findall(r"\bactual:\s*([\d.]+)\s*MT/s", chunk, re.I)
        specs = re.findall(r"\bspec:\s*([\d.]+)\s*MT/s", chunk, re.I)
        raw = re.findall(r"\bspeed:\s*([\d.]+)\s*MT/s", chunk, re.I)
        speeds.extend(actuals or specs or raw)
    return types, speeds, []


def ram_info() -> str:
    texts: list[tuple[str, str]] = []
    for cmd in (["dmidecode", "-t", "memory"], ["/usr/sbin/dmidecode", "-t", "memory"]):
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=1)
            if out.returncode == 0 and "Memory Device" in (out.stdout or ""):
                texts.append(("dmi", out.stdout))
                break
        except Exception:
            pass
    if not texts:
        try:
            out = subprocess.run(["inxi", "-mxxxx", "-c0"], capture_output=True, text=True, timeout=2)
            if out.returncode == 0 and "Memory" in (out.stdout or ""):
                texts.append(("inxi", out.stdout))
        except Exception:
            pass
    types, speeds, parts = [], [], []
    for kind, text in texts:
        types, speeds, parts = ram_from_dmidecode(text) if kind == "dmi" else ram_from_inxi(text)
        if types or speeds:
            break
    bits = []
    if types:
        ranked = [t for t in types if re.match(r"(LP)?DDR|GDDR|HBM", t, re.I)]
        pool = ranked or types
        bits.append(sorted(set(pool), key=pool.index)[0])
    if speeds:
        bits.append("%s MT/s" % sorted(set(speeds), key=speeds.index)[0])
    if parts and len(set(parts)) == 1:
        bits.append(parts[0])
    return " ".join(bits)


def collect_memory() -> dict[str, Any]:
    return {"info": ram_info()}


def system_power_profile() -> str:
    try:
        result = subprocess.run(
            ["omarchy-powerprofiles-list", "--active-state"],
            capture_output=True, text=True, timeout=3
        )
        for line in result.stdout.splitlines():
            parts = line.strip().split("\t")
            if len(parts) >= 2 and parts[1] == "1":
                return parts[0]
    except Exception:
        pass
    return ""


def collect_cpu() -> dict[str, Any]:
    topo = cpu_topology()
    return {
        "name": cpu_name(),
        "usagePct": 0.0,
        "temp": cpu_temp(),
        "freq": cpu_freq(),
        "power": cpu_power(),
        "cores": topo["cores"],
        "threads": topo["threads"],
        "governor": system_power_profile(),
    }


# ---------------------------------------------------------------- GPU

def gpu_busy() -> int:
    for p in sorted(glob.glob("/sys/class/drm/card*/device/gpu_busy_percent")):
        val = read_int(p)
        if val is not None:
            return val
    return 0


def gpu_temp() -> int:
    for p in sorted(glob.glob("/sys/class/drm/card*/device/hwmon/hwmon*/temp*_input")):
        label_file = p.replace("_input", "_label")
        label = read_str(label_file, "").lower()
        if "junction" in label or "edge" in label or "gpu" in label or "mem" in label or not label:
            val = read_int(p)
            if val is not None:
                return val // 1000
    return 0


def gpu_vram() -> tuple[float, float]:
    for card in sorted(glob.glob("/sys/class/drm/card*")):
        total = read_int(card + "/device/mem_info_vram_total")
        used = read_int(card + "/device/mem_info_vram_used")
        if total is not None and used is not None:
            return (round(used / 1_000_000_000, 1), round(total / 1_000_000_000, 1))
    return (0.0, 0.0)


def gpu_power() -> float:
    for p in sorted(glob.glob("/sys/class/drm/card*/device/hwmon/hwmon*/power1_average")):
        val = read_int(p)
        if val is not None:
            return round(val / 1_000_000, 1)
    return 0.0


def clean_gpu_name(name: str) -> str:
    if not name:
        return ""
    name = re.sub(r"\s*\([^)]*rev[^)]*\)", "", name)
    bracket_match = re.findall(r"\[([^\]]+)\]", name)
    product = None
    for bracket in bracket_match:
        if any(kw in bracket for kw in ["Radeon", "GeForce", "RX", "RTX", "GTX", "Arc"]):
            product = bracket
            break
    if not product and bracket_match:
        product = bracket_match[-1]
    if product:
        if "/" in product:
            variants = [v.strip() for v in product.split("/")]
            xt = [v for v in variants if "XT" in v or "XTX" in v]
            selected = max(xt, key=len) if xt else max(variants, key=len)
            if not selected.lower().startswith(("radeon", "geforce", "rx", "rtx", "gtx", "intel", "arc")):
                first_variant = variants[0]
                first_words = first_variant.split()
                prefix_parts = []
                for w in first_words:
                    if any(c.isdigit() for c in w):
                        break
                    prefix_parts.append(w)
                brand_prefix = " ".join(prefix_parts)
                if brand_prefix and not selected.lower().startswith(brand_prefix.strip().lower()):
                    selected = brand_prefix.strip() + " " + selected
            product = selected
        name = product
    name = re.sub(r"[\[\]]", "", name)
    name = re.sub(r"^(AMD/ATI|ATI|Advanced Micro Devices, Inc\.?)\s*", "", name, flags=re.IGNORECASE)
    name = name.strip()
    if not name:
        return ""
    if "radeon" in name.lower() or "navi" in name.lower():
        name = f"AMD {name}" if not name.lower().startswith("amd ") else name
    elif any(kw in name.lower() for kw in ["geforce", "rtx", "gtx", "nvidia"]):
        name = f"NVIDIA {name}" if not name.lower().startswith("nvidia ") else name
    return " ".join(name.split())


def gpu_name() -> str:
    try:
        result = subprocess.run(["lspci"], capture_output=True, text=True, timeout=3)
        for line in result.stdout.splitlines():
            if "VGA" in line or "Display" in line:
                parts = line.split(": ", 1)
                if len(parts) >= 2:
                    name = clean_gpu_name(parts[1].strip())
                    if name:
                        return name
    except Exception:
        pass
    return "GPU"


def gpu_nvidia() -> dict[str, Any] | None:
    # /sys/class/drm/*/device/{gpu_busy_percent,mem_info_vram_*} is an
    # AMDGPU-only sysfs interface -- the NVIDIA driver never populates it, so
    # collect_gpu() falls back here instead of reporting unavailable.
    try:
        result = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=3,
        )
        if result.returncode != 0 or not result.stdout.strip():
            return None
        parts = [p.strip() for p in result.stdout.strip().splitlines()[0].split(",")]
        if len(parts) < 6:
            return None
        name, util, temp, mem_used, mem_total, power = parts
        return {
            "available": True,
            "name": name,
            "usagePct": int(float(util)),
            "temp": int(float(temp)),
            # nvidia-smi reports MiB; divide by 1024 (not 1e9-scaled bytes)
            # so a 16 GiB card reads "~15.9", matching how it's marketed and
            # how nvidia-smi itself displays it -- not the technically-true
            # but confusing 17.1 decimal GB.
            "vramUsedGb": round(float(mem_used) / 1024, 1),
            "vramTotalGb": round(float(mem_total) / 1024, 1),
            "power": round(float(power), 1),
        }
    except Exception:
        return None


def collect_gpu() -> dict[str, Any]:
    vram_used, vram_total = gpu_vram()
    if vram_total == 0 and gpu_busy() == 0:
        nvidia = gpu_nvidia()
        if nvidia is not None:
            return nvidia
        return {"available": False, "usagePct": 0, "temp": 0, "vramUsedGb": 0, "vramTotalGb": 0, "name": ""}
    return {
        "available": True,
        "name": gpu_name(),
        "usagePct": gpu_busy(),
        "temp": gpu_temp(),
        "vramUsedGb": vram_used,
        "vramTotalGb": vram_total,
        "power": gpu_power(),
    }


# ---------------------------------------------------------------- Storage

def disk_model(mountpoint: str) -> str:
    """Physical-disk model backing a mountpoint (walks past LUKS/LVM/subvolumes)."""
    try:
        src = subprocess.run(["findmnt", "-no", "SOURCE", mountpoint],
                              capture_output=True, text=True, timeout=1).stdout.strip()
        src = src.split("[", 1)[0].strip()   # drop btrfs "[/@subvol]" suffix
        if not src:
            return ""
        out = subprocess.run(["lsblk", "-inso", "NAME,MODEL,TYPE", src],
                              capture_output=True, text=True, timeout=1).stdout
        for line in out.splitlines():
            parts = line.split()
            if parts and parts[-1] == "disk":
                return " ".join(parts[1:-1])
    except Exception:
        pass
    return ""


def collect_storage() -> dict[str, Any]:
    raw: list[dict[str, Any]] = []
    seen_devices: set[str] = set()

    skip_fs = {
        "tmpfs", "devtmpfs", "proc", "sysfs", "cgroup", "cgroup2",
        "efivarfs", "devpts", "pstore", "securityfs", "bpf", "autofs",
        "debugfs", "tracefs", "hugetlbfs", "mqueue", "configfs",
        "overlay", "fuse.gvfsd-fuse",
    }
    skip_paths = {"/boot", "/boot/efi", "/efi", "/recovery"}

    try:
        with open("/proc/self/mountinfo") as f:
            for line in f:
                parts = line.split()
                if len(parts) < 10:
                    continue
                dev_id = parts[2]       # major:minor
                mountpoint = parts[4]   # mount path
                fstype = parts[-3]      # filesystem type

                if fstype in skip_fs:
                    continue
                if mountpoint in skip_paths:
                    continue
                if dev_id in seen_devices:
                    continue

                try:
                    s = os.statvfs(mountpoint)
                    total = s.f_blocks * s.f_frsize
                    if total <= 0:
                        continue
                    free = s.f_bfree * s.f_frsize
                    used = total - free
                    seen_devices.add(dev_id)

                    pct = round(used / total * 100, 1) if total > 0 else 0
                    raw.append({
                        "path": os.path.normpath(mountpoint),
                        "usagePct": pct,
                        "usedGb": round(used / 1_000_000_000, 1),
                        "totalGb": round(total / 1_000_000_000, 1),
                        "model": disk_model(mountpoint),
                    })
                except Exception:
                    pass
    except Exception:
        pass

    raw.sort(key=lambda m: len(m["path"]))
    return {"mounts": raw}


# ---------------------------------------------------------------- Main

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compartments", default="cpu,gpu,storage",
                        help="Comma-separated list of compartments to collect")
    args = parser.parse_args()

    wanted = set(args.compartments.split(","))
    result = {}
    if "cpu" in wanted:
        result["cpu"] = collect_cpu()
    if "gpu" in wanted:
        result["gpu"] = collect_gpu()
    if "storage" in wanted:
        result["storage"] = collect_storage()
    if "memory" in wanted:
        result["memory"] = collect_memory()

    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
