# Atari 8-bit OS ROM: CIO, SIO, Vectors, and Floating Point

The Atari OS exposes services through a fixed **jump vector table at
`$E450-$E47F`** (stable across OS revisions, like the C64 KERNAL table) and a
device-independent I/O system (CIO). All of `$D800-$FFFF` is ROM on the 400/800
(bankable on XL/XE via PORTB `$D301`).

## OS jump vector table (`$E450-$E47F`)

| Addr | Name | Function |
|------|------|----------|
| `$E450` | DISKIV | disk handler init |
| `$E453` | DSKINV | disk handler (call with DCB set up) |
| `$E456` | **CIOV** | Central I/O — the main I/O entry; X = IOCB index (file# × 16) |
| `$E459` | **SIOV** | Serial I/O — low-level device I/O via the DCB |
| `$E45C` | SETVBV | set a vertical-blank timer/vector |
| `$E45F` | SYSVBV | system VBLANK entry |
| `$E462` | XITVBV | exit VBLANK |
| `$E465` | SIOINV | SIO init |
| `$E468` | SENDEV | send enable |
| `$E46B` | INTINV | interrupt handler init |
| `$E46E` | CIOINV | CIO init |
| `$E471` | BLKBDV | blackboard (self-test) |
| `$E474` | WARMSV | warm-start entry |
| `$E477` | COLDSV | cold-start entry |
| `$E47A` | RBLOKV | cassette read block |
| `$E47D` | CSOPIV | cassette open for input |

## CIO — Central I/O (the normal way to do I/O)

CIO is device-independent: you talk to named devices (`E:` screen editor, `S:`
screen, `K:` keyboard, `P:` printer, `C:` cassette, `D:` disk, `R:` serial)
through one of **8 IOCBs** (I/O Control Blocks) at `$0340-$03BF`, 16 bytes each.

To perform I/O: set up the IOCB fields, load `X` with the IOCB number × 16, and
`JSR CIOV` (`$E456`). Key IOCB offsets (relative to `$0340 + 16*n`):

| Offset | Name | Meaning |
|--------|------|---------|
| +0 | ICHID | device handler index (set by OS) |
| +1 | ICDNO | device number |
| +2 | ICCOM | **command** (e.g. 3 OPEN, 5 GET, 7 GETCHARS, 9 PUTCHARS, 11 PUTBYTE, 12 CLOSE) |
| +3 | ICSTA | status (returned) |
| +4-5 | ICBAL/H | buffer address |
| +8-9 | ICBLL/H | buffer length |
| +10 | ICAX1 | aux 1 (open mode) |
| +11 | ICAX2 | aux 2 |

A single-character print is: put char in A, set ICCOM=PUTCHARS on IOCB 0 (the
screen editor `E:`), `JSR CIOV`. The OS also keeps a simpler path for character
output via the editor handler. When porting, a `JSR CIOV` is "do the I/O command
described by IOCB X" — model it as a typed call against the device the IOCB was
opened to.

## SIO — Serial I/O

`SIOV` (`$E459`) drives the serial bus (disk, cassette, etc.) via a Device
Control Block at `$0300-$030B` (DDEVIC, DUNIT, DCOMND, DSTATS, DBUFLO/HI,
DTIMLO, DBYTLO/HI). Application code usually goes through CIO, which calls SIO
underneath; you'll see direct SIOV use in fast loaders and custom disk code.

## Floating-point package (`$D800-$DFFF`)

Atari's FP is a 6-byte BCD format (1 exponent byte + 5 mantissa BCD bytes),
distinct from the binary Microsoft format used by Applesoft/C64 BASIC. The two
FP registers are in zero page: **FR0 `$D4-$D9`**, **FR1 `$E0-$E5`** (FR2 `$E6`).

| Addr | Name | Function |
|------|------|----------|
| `$D800` | AFP | ASCII string (at `INBUFF`) → FR0 |
| `$D8E6` | FASC | FR0 → ASCII string (at `LBUFF`) |
| `$D9AA` | IFP | integer (FR0 low word) → FR0 floating |
| `$D9D2` | FPI | FR0 floating → integer |
| `$DA60` | FSUB | FR0 = FR0 − FR1 |
| `$DA66` | FADD | FR0 = FR0 + FR1 |
| `$DADB` | FMUL | FR0 = FR0 × FR1 |
| `$DB28` | FDIV | FR0 = FR0 ÷ FR1 |
| `$DD40` | PLYEVL | polynomial evaluation |
| `$DDB6` | FMOVE | FR0 → FR1 |
| `$DDC0` | EXP | e^FR0 |
| `$DECD` | LOG | ln(FR0) |

(The transcendental and load/store-by-pointer entries — FLD0R `$DD89`, FST0R
`$DDA7`, EXP10, LOG10 — also live here; verify exact addresses against "De Re
Atari" or "Mapping the Atari" for the specific OS revision.)

Because Atari FP is **decimal (BCD)**, do not assume the same bit layout as the
Apple/C64 binary floats — when porting, treat it as its own format and convert
at the boundaries (or call AFP/FASC to go through the ASCII representation).

## Key OS zero-page / page-2 variables for porting

| Addr | Name | Meaning |
|------|------|---------|
| `$0014-$0016` | RTCLOK | 3-byte frame counter (jiffy clock), incremented each VBLANK |
| `$0054` | ROWCRS | text cursor row |
| `$0055-$0056` | COLCRS | text cursor column |
| `$0058-$0059` | SAVMSC | start of screen memory |
| `$006A` | RAMTOP | top of RAM, in pages |
| `$02FC` | CH | last keyboard code read (`$FF` = none) |
| `$0011` | BRKKEY | BREAK-key flag |
| `$0200-$0217` | interrupt vectors | VDSLST (DLI), VVBLKI/D (VBLANK), VKEYBD, VTIMR1-4… (see atari8-memory.md) |

A program that "reads the clock" does `LDA RTCLOK+2` etc.; one that hooks the
display-list interrupt stores its handler into `VDSLST` (`$0200`) and enables it
via `NMIEN` (`$D40E`). Map these to explicit timer/interrupt concepts in the
port rather than to raw memory.
