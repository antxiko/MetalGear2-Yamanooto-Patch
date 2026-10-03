# Metal Gear 2: Solid Snake — saves on the Yamanooto

*[Español](README.es.md)*

Metal Gear 2 saves to the **Game Master 2** or to disk. The patch makes it believe the Game Master 2 is plugged in and **answers its calls itself**, writing the game's **three files** (SNAK1, SNAK2 and SNAK3) to the cartridge's flash. No Game Master 2, no disk drive.

**39** bytes changed in **3** stretches · **8 KB** driver · one **64 KB** sector · no ROM distributed

## How to play

As with the Game Master 2: the game's own save menu offers the cartridge instead of the passwords, with its three files, and you load from the same place.

## What you need

- **The game ROM**, which this repository does not distribute: *Metal Gear 2: Solid Snake* (Konami, 1990, RC-767), the Japanese one, 524,288 bytes, sha256 `43b7fab533abeb87313919ec1fc7bc732d7b0ebfacede1e4f89d8295160384f2`. The patcher checks every site, so with another dump it refuses instead of breaking it.
- **Python 3.**
- **A Yamanooto**, 2 MB or 8 MB, in an MSX2.

## Building the image

```
python tools/imagen.py metalgear2.rom
```

You get `metalgear2_yamanooto.rom` (640 KB), ready to flash from the start of the flash: it boots the game on its own, with no menu. **Flashing it replaces the menu and games on the cartridge.** In openMSX, with an MSX2 machine:

```
openmsx -machine <an MSX2> -cart metalgear2_yamanooto.rom -romtype Yamanooto
```

`make test` runs the 4 tests: the `.bin` files come from their `.asm`, the patcher refuses another ROM and, with the ROM in the root, outside the stretches the patcher declares the game is the original byte for byte and the image is the reference one.

## How it works

- At 0x5DD4, the routine that looks for the Game Master 2 in the slots is replaced by 7 bytes saying it is in the game's own slot.
- At 0x186D4, the only routine the game uses to call into another slot, instead of jumping to the Game Master 2 it puts the driver ([launcher/mg2_driver.asm](launcher/mg2_driver.asm), 8 KB appended as bank 0x40) in the 0x8000 window through SCC register 0x9000 and calls it.
- The driver answers like the Game Master 2: it reads (function 0x08) and writes (0x09) the files; every other function answers that all went well, which is the only thing the game looks at.
- The game is already Konami SCC, the mode a Yamanooto starts in: from the start of the flash it boots on its own.
- Each file is `[0xA5][2-byte length][115 bytes of data]`, every 0x100 bytes of a 64 KB flash sector (relative bank 0x48). To write one, all three are copied to RAM, the sector is erased and they are reprogrammed from an engine in RAM (0xE500).

## Where it comes from

It comes from [nPackR](https://github.com/antxiko/msx-yamanooto-npackr), which uses it to put the game in a collection. Here it comes on its own: the image boots the game directly, with no menu. GPL v3 licence ([LICENSE](LICENSE)) and a non-commercial note ([NOTICE.md](NOTICE.md)).

## Tested

In openMSX.
