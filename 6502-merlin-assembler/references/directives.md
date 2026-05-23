# Merlin Directives (Pseudo-Opcodes)

What each directive emits or does. Byte order matters for porting — note
especially DW/DA vs DDB. Directives marked **[16/32]** are Merlin 16/32 (IIgs /
65816) additions; the rest are core and present in Merlin 8 / Merlin 64.

## Origin, equates, storage

| Directive | Syntax | Effect |
|-----------|--------|--------|
| ORG | `ORG $0300` | set assembly origin (where code is assumed to load/run). Merlin 32 default is `$8000`. With no operand, re-establishes the PC. |
| EQU / = | `LABEL EQU $C000` / `LABEL = 5` | define a constant. Forward references not allowed. |
| DUM / DEND | `DUM $00` … `DEND` | "dummy" section: assign label values (e.g. a struct overlay) but emit **no** object code. Classic way to lay out a zero-page record. |
| DS | `DS 16` / `DS 16,$FF` / `DS \,$00` | reserve N bytes (filled with 0 or a given value). `DS \` fills to the next page boundary. |
| HEX | `HEX 0102030F` / `HEX 01,02` | raw hex bytes; digits packed two per byte, optional commas. |

## Data: bytes, words, addresses

| Directive | Emits | Byte order |
|-----------|-------|-----------|
| DFB / DB | one byte per operand (`DFB $12,$34,LABEL`) | n/a |
| DW / DA | 2 bytes per operand | **low byte first** (little-endian) |
| DDB | 2 bytes per operand | **high byte first** (big-endian) — the odd one |
| ADR **[16/32]** | 3 bytes (24-bit address) | low byte first |
| ADRL **[16/32]** | 4 bytes (long address) | low byte first |

`DFB` accepts decimal, `$hex`, `%binary`, char literals, and arithmetic
expressions (evaluated left-to-right). `DA`/`DW` are the normal way to lay down
a pointer table; `DDB` is rare and exists for big-endian data structures — don't
assume word directives are little-endian without checking which one is used.

## Strings (delimiter chooses high-bit handling)

The Apple II stores "normal" text as high-bit-**set** ASCII; the delimiter you
choose controls bit 7. Convention in Merlin: single quotes `'…'` → high bit
clear; double quotes `"…"` → high bit set.

| Directive | Emits |
|-----------|-------|
| ASC | the literal characters (high bit per the delimiter) |
| DCI | like ASC but the **last** character has the opposite high bit (Dextral Character Inverted) — a classic length-free string terminator |
| INV | inverse-video character codes (uppercase/specials) |
| FLS | flashing character codes |
| REV | the string **reversed** (last char first) |
| STR | a leading **length byte**, then ASC data (Pascal-style string) |
| STRL **[16/32]** | leading length **word**, then the data |

## Control flow / conditional assembly

| Directive | Syntax | Effect |
|-----------|--------|--------|
| LUP / `--^` | `LUP 5` … `--^` | repeat the enclosed lines N times at assembly time (≤ $8000). `@`-labels get auto-renamed per iteration. |
| DO / ELSE / FIN | `DO expr` … `ELSE` … `FIN` | assemble the block only if `expr` ≠ 0. Nestable. |
| IF / ELSE / FIN **[16/32]** | `IF MX-flag test` | conditional on 65816 M/X register-width state (or a variable's first char). |
| ERR | `ERR expr` | force an assembly error if `expr` ≠ 0 (assertions, range checks). |
| END | `END` | stop assembling; ignore the rest of the file. |
| CHK | `CHK` | emit a checksum byte (XOR of preceding bytes). |
| LST | `LST ON` / `LST OFF` | listing control (no code effect). |

## File inclusion and output

| Directive | Effect |
|-----------|--------|
| PUT filename | include a **source** file (textually) at this point |
| USE filename | include a file, by convention a macro/equates library (`*.Macs.s`) |
| PUTBIN filename **[16/32]** | include a **binary** file as hex data |
| SAV filename | save the assembled object to disk (Merlin 8/16; ignored by Merlin 32) |
| DSK filename **[16/32]** | name the output object file |
| DAT | emit the current date/time (`DAT 1`..`DAT 8` choose format) |

## 65816 / IIgs and segment directives **[16/32]**

These appear in IIgs source and Merlin-32 link files; if you see them you are
looking at 16-bit / OMF-targeted code.

| Directive | Effect |
|-----------|--------|
| XC | enable extended CPU: one `XC` = 65C02, two `XC` = 65816 |
| MX %nn | tell the assembler the current 16/8-bit state of the M and X flags (so it sizes immediates correctly). Does **not** emit code — it must match the runtime `REP`/`SEP` state or the listing desynchronizes. |
| REL | produce relocatable (OMF) code |
| TYP / AUX | set GS/OS file type / auxtype |
| EXT / ENT | declare a label external (imported) / entry (exported) for the linker |
| KND, SNA, LNA, ALI, ORG (link) | segment kind, segment/load names, alignment, origin — used in Merlin 32 link files |

## Quick byte-order reminder

```
        DA  $1234     ; emits  34 12     (low, high)
        DDB $1234     ; emits  12 34     (high, low)
        DFB $12,$34   ; emits  12 34     (as written)
```
When porting a table, always confirm which word directive produced it.
