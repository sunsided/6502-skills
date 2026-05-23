# Commodore 64 Memory Map, Banking, and I/O Registers

The C64 has 64K RAM but overlays ROM and I/O on top of it; what is visible at
`$A000-$BFFF`, `$D000-$DFFF`, and `$E000-$FFFF` depends on the **6510 processor
port** at `$0001`. The CPU is a 6510 — a 6502 with an on-chip I/O port — so the
instruction set is identical to the 6502 (use the 6502-instruction-set skill).

## The 6510 processor port — `$0000` / `$0001`

- `$0000` = data direction register (default `$2F`: bits 0-5 outputs).
- `$0001` = the port. Default `$37`.

Bits 0-2 control memory banking; bits 3-5 drive the Datasette:

| Bits 2-0 of `$01` | `$A000-$BFFF` | `$D000-$DFFF` | `$E000-$FFFF` |
|-------------------|---------------|----------------|----------------|
| `111` (default 7) | BASIC ROM | I/O | KERNAL ROM |
| `110` (6) | RAM | I/O | KERNAL ROM |
| `101` (5) | RAM | I/O | RAM |
| `100` (4) | RAM | RAM | RAM |
| `011` (3) | BASIC ROM | CHAR ROM | KERNAL ROM |
| `010` (2) | RAM | CHAR ROM | KERNAL ROM |
| `001` (1) | RAM | CHAR ROM | RAM |
| `000` (0) | RAM | RAM | RAM |

Two bits really matter: **bit 0 LORAM** (BASIC ROM in/out), **bit 1 HIRAM**
(KERNAL ROM in/out), **bit 2 CHAREN** (0 → character ROM visible at `$D000`
instead of I/O). Bit 3 = cassette write, bit 4 = cassette sense, bit 5 =
cassette motor. Demos/games commonly poke `$01` to `$35` (RAM + I/O, no ROM) or
`$34` (all RAM) to free the ROM space — so a `STA $01` is a banking change you
must track.

## Overall layout

| Range | Use |
|-------|-----|
| `$0000-$00FF` | zero page (`$00/$01` = processor port; BASIC/KERNAL pointers below) |
| `$0100-$01FF` | 6502 stack |
| `$0200-$02FF` | BASIC input buffer + system tables; `$0277` keyboard buffer |
| `$0300-$03FF` | BASIC/KERNAL vectors (`$0314` IRQ, `$0316` BRK, `$0318` NMI) |
| `$0400-$07FF` | default **screen RAM** (1000 bytes + sprite pointers at `$07F8-$07FF`) |
| `$0800-$9FFF` | BASIC program + variables (program starts `$0801`) |
| `$A000-$BFFF` | BASIC ROM (8K) — or RAM |
| `$C000-$CFFF` | free RAM (4K, not banked — popular for ML routines) |
| `$D000-$DFFF` | I/O (VIC/SID/color/CIA) — or CHAR ROM — or RAM |
| `$E000-$FFFF` | KERNAL ROM (8K) — or RAM |

## VIC-II video chip — `$D000-$D02E`

| Addr | Register |
|------|----------|
| `$D000-$D00F` | sprite 0-7 X,Y position pairs |
| `$D010` | sprite X position bit 8 (MSBs) |
| `$D011` | control reg 1: bit7 raster bit8, ECM, BMM (bitmap), DEN (display enable), RSEL, bits0-2 Y-scroll |
| `$D012` | raster line (read = current; write = compare for raster IRQ) |
| `$D015` | sprite enable bits |
| `$D016` | control reg 2: MCM (multicolor), CSEL, bits0-2 X-scroll |
| `$D017` | sprite Y-expand |
| `$D018` | memory pointers: screen RAM base (bits 7-4) and char/bitmap base (bits 3-1) |
| `$D019` | interrupt status (raster, sprite collisions) |
| `$D01A` | interrupt enable mask |
| `$D01B` | sprite-to-background priority |
| `$D01C` | sprite multicolor enable |
| `$D01D` | sprite X-expand |
| `$D01E` / `$D01F` | sprite-sprite / sprite-background collision |
| `$D020` | **border color** |
| `$D021` | background color 0 |
| `$D022-$D024` | background colors 1-3 (multicolor/ECM) |
| `$D025` / `$D026` | sprite multicolor 0 / 1 |
| `$D027-$D02E` | sprite 0-7 colors |

`$D000-$D3FF` mirrors the 47 registers every 64 bytes. Color RAM is separate.

## SID sound chip — `$D400-$D41C`

| Addr | Register |
|------|----------|
| `$D400/$D401` | voice 1 frequency lo/hi |
| `$D402/$D403` | voice 1 pulse width lo/hi |
| `$D404` | voice 1 control: gate (bit0), sync, ring, test, waveform bits (tri/saw/pulse/noise) |
| `$D405/$D406` | voice 1 attack/decay, sustain/release |
| `$D407-$D40D` | voice 2 (same layout) |
| `$D40E-$D414` | voice 3 (same layout) |
| `$D415/$D416` | filter cutoff lo/hi |
| `$D417` | filter resonance + voice routing |
| `$D418` | **master volume** (bits0-3) + filter mode |
| `$D419/$D41A` | paddle X/Y (read) |
| `$D41B` | voice 3 oscillator (read, "random") |
| `$D41C` | voice 3 envelope (read) |

## Color RAM — `$D800-$DBFF`

1000 nybbles (low 4 bits used), one per screen cell; sets each character's
foreground color. It is *not* affected by `$01` banking the way ROM is — it is
always at `$D800` when I/O is enabled.

## CIA #1 — `$DC00` (keyboard, joysticks, timers, IRQ source)

| Addr | Register |
|------|----------|
| `$DC00` | port A — keyboard matrix columns / joystick port 2 |
| `$DC01` | port B — keyboard matrix rows / joystick port 1 |
| `$DC02/$DC03` | data direction A / B |
| `$DC04-$DC07` | timer A / timer B (lo/hi) |
| `$DC08-$DC0B` | time-of-day clock |
| `$DC0D` | interrupt control/status (timer underflow → IRQ) |
| `$DC0E/$DC0F` | control timer A / B |

## CIA #2 — `$DD00` (VIC bank, serial bus, NMI, user port)

| Addr | Register |
|------|----------|
| `$DD00` | port A — bits 0-1 select the VIC 16K bank; serial bus lines |
| `$DD01` | port B — RS-232 / user port |
| `$DD0D` | NMI control/status |

`$DD00` bits 0-1 invert-select which 16K of RAM the VIC-II sees — a common
gotcha: VIC addresses are relative to the selected bank, not absolute.

## Key zero-page BASIC/KERNAL pointers

| Addr | Name | Meaning |
|------|------|---------|
| `$2B-$2C` | TXTTAB | start of BASIC program (`$0801`) |
| `$2D-$2E` | VARTAB | start of variables |
| `$2F-$30` | ARYTAB | start of arrays |
| `$31-$32` | STREND | end of arrays |
| `$33-$34` | FRETOP | bottom of string heap |
| `$37-$38` | MEMSIZ | top of BASIC RAM (`$A000`) |
| `$61-$66` | FAC1 | BASIC floating-point accumulator |
| `$69-$6E` | FAC2/ARG | floating-point argument |
| `$7A-$7B` | TXTPTR | CHRGET program pointer |
| `$73-$8A` | CHRGET | self-modifying next-byte routine (in zero page) |
| `$90` | STATUS (ST) | KERNAL I/O status byte |
| `$C5` | last key pressed (matrix code) |
| `$D1-$D2` | pointer to current screen line |
| `$0286` | current character color |
| `$0314-$0315` | CINV — IRQ vector |
| `$0316-$0317` | CBINV — BRK vector |
| `$0318-$0319` | NMINV — NMI vector |
