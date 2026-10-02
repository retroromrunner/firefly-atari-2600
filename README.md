# FIREFLY — Atari 2600

A minimal, clean Atari 2600 proof-of-concept game. Built as a starting point for new Atari 2600 homebrew projects.

![FIREFLY gameplay](screenshot.png)

## What it does

- **Title screen**: `FIREFLY` block text, blinking yellow firefly dot, blinking `PRESS FIRE`
- **Gameplay**: Press fire to start. Joystick moves the blinking firefly around a walled playfield. The firefly stops at the walls — it can't leave the screen.
- **Embers & score**: A blinking ember (missile 0) appears at a random spot. Fly into it to collect it for **+1** — the score (00–99, BCD) shows at the top of the screen in TIA score mode, and a new ember spawns elsewhere.

## Files

- `firefly.asm` — full 6502 assembly source (DASM syntax)
- `firefly.bin` — assembled 4K ROM, ready to run in Stella, RetroArch, or real hardware

## Building

You need [DASM](https://dasm-assembler.github.io/):

```bash
dasm firefly.asm -f3 -ofirefly.bin
# ensure exactly 4096 bytes with vectors at $FFFA-$FFFF
```

## How it works

- **Kernel**: 262-scanline frame (3 VSYNC + 37 VBLANK + 192 playfield + 30 overscan)
- **Title**: playfield text via a 4px block font, ball sprite for the firefly dot
- **Game**: ball sprite (8px, `CTRLPF=$31`) for the firefly, missile 0 (4px, `NUSIZ0=$20`) for the ember, playfield for the yellow wall border
- **Score**: BCD 00–99 in zero page, `sed`/`adc #1` on collect, digit pointers computed in VBLANK, drawn in 8 score-mode lines at the top of the kernel (`CTRLPF=$02`; in score mode the player digits take `COLUP0`/`COLUP1` — not `COLUPF` — so all three are set white)
- **RNG**: 8-bit LFSR (`eor #$B4`) for ember spawn positions
- **Collision**: software distance check (|dx|<9, |dy|<11) — simpler and more predictable than the TIA collision latches here
- **Input**: `SWCHA` joystick, `INPT4` fire button
- **Positioning**: classic divide-by-15 `PosX`/`PosXBall` routines with `HMOVE` fine adjust

## Lessons baked in

This ROM was debugged the hard way — see the dev.to article for the full story:
- The TIA ball/player must be drawn for a bounded set of scanlines; enabling it across all 192 lines can glitch
- `BlankLines`-style helpers must handle a zero count (X=0 loops 256 times with `dex`/`bne`!)
- Clear TIA motion registers (`HMCLR`) when switching screens or you get phantom artifacts
- Clamp positions *before* drawing, and guard `dec`/`inc` against wraparound instead of clamping after

## License

Public domain. Do whatever you want with it.
