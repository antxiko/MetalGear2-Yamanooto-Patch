#!/usr/bin/env python3
"""
mg2_to_yamanooto.py — patch Metal Gear 2: Solid Snake to save to Yamanooto flash.

MG2 normally saves through a Game Master 2 companion cartridge (or a disk). We
neither embed GM2 nor emulate disk: we patch MG2's two save touch-points and
append our own 8KB micro-driver bank (mg2_driver.bin) that answers MG2's
GM2-shaped calls and writes straight to flash.

Patches (verified against the GoodMSX dump, KonamiSCC 512KB):
  (1) ROM 0x5DD4 (GM2 detection): make MG2 believe GM2 sits in its own slot, so
      the save menu offers cartridge saving instead of passwords.
        01 00 04 21 C1 FC 09  ->  3A 99 C3 32 8A C3 C9
        (LD A,(C399) / LD (C38A),A / RET)
  (2) ROM 0x186D4 (the single inter-slot call helper): instead of ENASLT'ing a
      GM2 slot, map our driver bank (relative bank 0x40) into the 0x8000 window
      via the SCC register 0x9000 and CALL 0x8000. Restores MG2's shadow after.

The driver bank is appended right after MG2's 512KB (relative bank 0x40); the
packager (mapper "mg2") reserves three 64KB save sectors at relative banks
0x48/0x50/0x58 (SNAK1/2/3).

Usage:
  mg2_to_yamanooto.py in.rom out.rom
(needs launcher/mg2_driver.bin, built from mg2_driver.asm + mg2_engine.asm)
"""

import sys
from pathlib import Path

DRV_BANK = 0x40   # relative flash bank of the appended driver

P1_OFF = 0x5DD4
# LD BC,0x0400 / LD HL,0xFCC1 / PUSH BC — the enumerator's entry (only entered
# at its start, so overwriting the first 7 bytes with a self-contained stub +
# RET is safe; the rest of the old routine becomes dead code).
P1_OLD = bytes.fromhex("01000421c1fcc5")
P1_NEW = bytes.fromhex("3a99c3328ac3c9")

P2_OFF = 0x186D4
# original helper (33 bytes) — sanity check
P2_OLD = bytes.fromhex(
    "c53a8ac32680cd2400"    # PUSH BC / LD A,(C38A) / LD H,80 / CALL 0024
    "3e04320080"            # LD A,04 / LD (8000),A
    "c1ed5b90c3"            # POP BC / LD DE,(C390)
    "cd0080"               # CALL 8000
    "f53a99c32680cd2400"    # PUSH AF / LD A,(C399) / LD H,80 / CALL 0024
    "f1c9")               # POP AF / RET
P2_NEW = bytes(
    [0x3A, 0x82, 0xC3,           # LD A,(C382)   read 0x8000-window shadow bank
     0xF5,                       # PUSH AF       stash shadow on the stack
     0x3E, DRV_BANK,             # LD A,DRV
     0x32, 0x00, 0x90,           # LD (9000),A   map driver into 0x8000 (SCC reg)
     0xED, 0x5B, 0x90, 0xC3,     # LD DE,(C390)  param block -> DE
     0xCD, 0x00, 0x80,           # CALL 8000     our driver (C=func, DE=param); A=return
     0x08,                       # EX AF,AF'     PRESERVE the driver's A (return code)
     0xF1,                       # POP AF        A = shadow bank
     0x32, 0x00, 0x90,           # LD (9000),A   restore the game's 0x8000 bank
     0x08,                       # EX AF,AF'     A = driver return code again
     0xC9]                       # RET           MG2 sees the real return code
) + b"\x00" * 10                 # pad to the original 33 bytes


def convert(rom: bytes, driver: bytes) -> tuple[bytes, dict]:
    if len(rom) != 512 * 1024:
        raise RuntimeError(f"MG2 ROM must be 512KB, got {len(rom)}")
    if len(driver) != 0x2000:
        raise RuntimeError(f"driver must be one 8KB bank, got {len(driver)}")
    out = bytearray(rom)
    stats = {}

    if bytes(out[P1_OFF:P1_OFF + 7]) != P1_OLD:
        raise RuntimeError(f"detection bytes at 0x{P1_OFF:04X} don't match — wrong dump?")
    out[P1_OFF:P1_OFF + 7] = P1_NEW
    stats["detection_patch"] = 1

    if bytes(out[P2_OFF:P2_OFF + len(P2_OLD)]) != P2_OLD:
        raise RuntimeError(f"call-helper bytes at 0x{P2_OFF:04X} don't match — wrong dump?")
    out[P2_OFF:P2_OFF + len(P2_NEW)] = P2_NEW
    stats["helper_patch"] = 1

    # append the driver as relative bank 0x40 (right after the 64 game banks)
    assert len(out) == DRV_BANK * 0x2000
    out += driver
    stats["driver_appended"] = len(driver)
    return bytes(out), stats


def load_driver(base: Path) -> bytes:
    return (base / "mg2_driver.bin").read_bytes()


def main():
    if len(sys.argv) != 3:
        print("Usage: mg2_to_yamanooto.py in.rom out.rom", file=sys.stderr)
        sys.exit(1)
    import hashlib
    src = Path(sys.argv[1]).read_bytes()
    here = Path(__file__).resolve().parent.parent / "launcher"
    driver = load_driver(here)
    dst, stats = convert(src, driver)
    Path(sys.argv[2]).write_bytes(dst)
    print(f"MG2 patched for Yamanooto saves: {stats} "
          f"(sha1 {hashlib.sha1(src).hexdigest()[:12]})")
    print("Pack with `mapper = \"mg2\"`.")


if __name__ == "__main__":
    main()
