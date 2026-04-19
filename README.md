# Balduin der Ball

A small 2D platformer for MS-DOS, written in 16-bit x86 assembly. Balduin, a bouncing ball, must collect every diamond on a level to advance to the next one, while avoiding water and spikes. Originally built as exercise 10 (`ueb10`) for an assembly programming course in 2004.

## Files

| File | Description |
|---|---|
| `ueb10.asm` | Full game source (MASM/TASM-style syntax, `.386`, `USE16`) |
| `balduin.exe` | Assembled DOS executable |
| `balduin_m.exe` | Alternate build (likely with debug/modified build flags) |
| `sprites.bmp` | Sprite sheet — 16×192, 8-bit indexed (12 sprites stacked 16×16) |
| `sprites_alternativ.bmp` | Alternate sprite sheet, swap in by renaming to `SPRITES.BMP` |
| `level001.bld` … `level005.bld` | Level data in the custom `BALD` format |

## Running

Requires a real DOS environment or emulator such as DOSBox:

```
dosbox balduin.exe
```

The loader expects `SPRITES.BMP` and `level001.bld` in the current directory; subsequent levels are discovered by incrementing the numeric suffix.

## Controls

| Key | Action |
|---|---|
| ← / → | Move left / right |
| ↑ | Jump |
| Esc | Quit |

The world wraps horizontally (cylinder world): walking off one edge brings you back on the other.

## Gameplay

- Collect every diamond in a level to unlock the next.
- Touching water, deep water, or spikes kills Balduin and restarts the current level.
- After clearing `level005.bld` the game prints a German win message (`Herzlichen Glueckwunsch!`) and exits to DOS.

## Technical notes

- Renders via VGA mode 13h (320×200, 256 colors) at `A000:0000` with double-buffering and vertical-retrace sync for tear-free animation.
- Installs a custom keyboard ISR (`tastenstatus` array) and restores the original handler on exit.
- Loads 8-bit BMP files directly — the BMP palette is programmed into the VGA DAC via port `3C8h`.
- Level files use a 16-byte header (`'BALD'` magic, stored little-endian as `'DLAB'` for dword compare, then width, height, reserved) followed by a width×height grid of sprite indices, up to 128×128 tiles.
- Sprite IDs used by the level format:

  | ID | Sprite |
  |---|---|
  | 0 | Sky |
  | 1 | Grass ground |
  | 2 | Earth ground |
  | 3 | Wall |
  | 4 | Water |
  | 5 | Deep water |
  | 6 | Spikes |
  | 7–10 | Diamond (animation frames) |
  | 11 | Balduin (spawn marker, replaced with sky at load time) |

## Building

The source targets a DOS assembler such as TASM or MASM 6.x, followed by a 16-bit linker to produce an `.exe`. Example with TASM:

```
tasm /zi ueb10.asm
tlink /v ueb10.obj
```
