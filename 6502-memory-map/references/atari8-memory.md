# Atari 400/800/XL/XE Memory Map and Custom Chips

The Atari 8-bit machines use a 6502 (≈1.79 MHz NTSC) plus four custom chips:
**ANTIC** and **GTIA/CTIA** (video), **POKEY** (sound, keyboard, serial, paddles,
RNG), and a **6520 PIA** (joystick/controller ports). Unlike the C64's banking,
the Atari leaves hardware permanently mapped at `$D000-$D7FF`; the distinctive
feature is the **shadow-register** system (page 2 RAM copies that the OS VBLANK
copies to the write-only hardware registers each frame).

## Overall layout

| Range | Use |
|-------|-----|
| `$0000-$007F` | OS zero page (timers, vectors, I/O control block, FMS) |
| `$0080-$00FF` | user / BASIC zero page (incl. FP registers FR0 `$D4`, FR1 `$E0`) |
| `$0100-$01FF` | 6502 stack |
| `$0200-$027F` | OS interrupt/timer vectors (RAM) — see atari8-os.md |
| `$0230-$0231` | SDLSTL/H — shadow of the ANTIC display-list pointer |
| `$0278-$027F` | STICK0-3 / STRIG0-3 — joystick & trigger shadows |
| `$02C0-$02C8` | PCOLR0-3, COLOR0-4 — player/playfield color shadows |
| `$0300-$03FF` | device control blocks: SIO DCB (`$0300`), the 8 CIO IOCBs (`$0340-$03BF`) |
| `$0480-$05FF` | OS / free RAM |
| `$0600-$06FF` | **page 6** — the classic free area for user machine code |
| `$0700-…` | DOS / FMS when loaded |
| `…-RAMTOP` | program, then the display list + screen RAM near top of RAM (`SAVMSC $58`) |
| `$8000-$9FFF` | cartridge B (16K carts use `$8000-$BFFF`) |
| `$A000-$BFFF` | cartridge A (8K, e.g. BASIC); RAM if no cart / banked out (XL/XE) |
| `$C000-$CFFF` | unused on 400/800; RAM or OS on XL/XE |
| `$D000-$D7FF` | **hardware registers** (GTIA / POKEY / PIA / ANTIC) |
| `$D800-$DFFF` | floating-point ROM |
| `$E000-$FFFF` | OS ROM (with the `$E450` vector table and `$FFFA-$FFFF` 6502 vectors) |

On the **XL/XE**, ROM is bankable (PORTB `$D301` bits control OS ROM, BASIC ROM,
and the "self-test" RAM under ROM); the OS is 16K and BASIC is built in. On the
400/800, OS ROM is 10K (`$D800-$FFFF`) and there is no built-in BASIC.

## GTIA / CTIA — video, color, player/missile (`$D000-$D01F`)

Most registers are **write-only**; reads at the same address return different
inputs (e.g. collision/console). Common write registers:

| Addr | Reg | Function |
|------|-----|----------|
| `$D000-$D003` | HPOSP0-3 | player horizontal positions |
| `$D004-$D007` | HPOSM0-3 | missile horizontal positions |
| `$D008-$D00C` | SIZEP0-3 / SIZEM | player / missile widths |
| `$D00D-$D011` | GRAFP0-3 / GRAFM | player / missile bit patterns |
| `$D012-$D015` | COLPM0-3 | player/missile colors |
| `$D016-$D019` | COLPF0-3 | playfield colors 0-3 |
| `$D01A` | COLBK | background/border color |
| `$D01B` | PRIOR | priority, player/playfield mix, GTIA modes |
| `$D01D` | GRACTL | player/missile DMA enable |
| `$D01E` | HITCLR | clear collision registers (write) |
| `$D01F` | CONSOL | read: START/SELECT/OPTION console keys; write: speaker |

Reads `$D000-$D00F` give the collision registers (M0PF…P3PL).

## POKEY — sound, keyboard, serial, paddles, RNG (`$D200-$D20F`)

POKEY registers are **dual-purpose** (write ≠ read at the same address):

| Addr | Write | Read |
|------|-------|------|
| `$D200/$D202/$D204/$D206` | AUDF1-4 (channel frequency) | POT0-3 (paddle values) |
| `$D201/$D203/$D205/$D207` | AUDC1-4 (control/volume) | POT4-7 |
| `$D208` | AUDCTL (clock/filters) | ALLPOT (paddle-trigger bits) |
| `$D209` | STIMER (start timers) | KBCODE (keyboard scan code) |
| `$D20A` | SKRES (status reset) | **RANDOM** (hardware RNG) |
| `$D20B` | POTGO (start paddle scan) | — |
| `$D20D` | SEROUT | SERIN (serial data) |
| `$D20E` | IRQEN (interrupt enable) | IRQST (interrupt status) |
| `$D20F` | SKCTL (serial/keyboard control) | SKSTAT (serial/keyboard status) |

`RANDOM` (`$D20A` read) is the go-to hardware random source. Sound is four
channels of frequency+volume; `AUDCTL` can pair channels for 16-bit pitch.

## PIA 6520 — controller ports (`$D300-$D303`)

| Addr | Reg | Function |
|------|-----|----------|
| `$D300` | PORTA | joysticks 1-2 (nibble each) — read via STICK shadows `$0278` |
| `$D301` | PORTB | joysticks 3-4 on 400/800; **memory-bank control on XL/XE** |
| `$D302/$D303` | PACTL/PBCTL | port control (DDR access, cassette motor, IRQ) |

## ANTIC — display DMA & timing (`$D400-$D40F`)

| Addr | Reg | Function |
|------|-----|----------|
| `$D400` | DMACTL | DMA control (playfield width, P/M DMA, DList DMA) — shadow SDMCTL `$022F` |
| `$D401` | CHACTL | character control (inverse/blank) — shadow CHACT `$02F3` |
| `$D402-$D403` | DLISTL/H | **display-list pointer** — shadow SDLSTL `$0230` |
| `$D404/$D405` | HSCROL/VSCROL | fine scroll |
| `$D407` | PMBASE | player/missile data base (page-aligned) |
| `$D409` | CHBASE | character-set base — shadow CHBAS `$02F4` |
| `$D40A` | WSYNC | halt CPU until horizontal blank (write) |
| `$D40B` | VCOUNT | scanline counter (read) |
| `$D40E` | NMIEN | NMI enable (DLI/VBI) |
| `$D40F` | NMIST / NMIRES | NMI status / reset |

The Atari screen is **not a fixed text buffer** — ANTIC executes a *display
list* (a small program at `SDLSTL`) that describes each mode line, and the
screen RAM lives wherever `SAVMSC` (`$58/$59`) points (near `RAMTOP $6A`). To
understand "what's on screen" you read the display list, not a fixed address.

## Shadow registers — the Atari idiom

Many hardware registers are write-only and are refreshed every frame from RAM
"shadows" in page 2 by the OS VBLANK routine. Application code usually writes the
**shadow**, not the hardware, so the value survives the next VBLANK:

| Shadow | Hardware | Meaning |
|--------|----------|---------|
| `$022F` SDMCTL | `$D400` DMACTL | DMA control |
| `$0230-$0231` SDLSTL/H | `$D402-$D403` | display-list pointer |
| `$02C0-$02C3` PCOLR0-3 | `$D012-$D015` | player/missile colors |
| `$02C4-$02C8` COLOR0-4 | `$D016-$D01A` | playfield + background colors |
| `$02F4` CHBAS | `$D409` CHBASE | character-set base |
| `$0278-$027B` STICK0-3 | `$D300/$D301` | joystick directions |
| `$0284-$0287` STRIG0-3 | (GTIA/PIA) | joystick triggers |
| `$0270-$0277` PADDL0-7 | POKEY POT0-7 | paddle positions |

When porting, a `STA $02C6` is "set playfield color 2 (next frame)", while a
`STA $D018` is "set it immediately this scanline" — both are real and mean
different things. Classify the address accordingly.
