# 6502 Addressing Modes

The NMOS 6502 has 13 addressing modes. The mode determines how the operand is
located and how many bytes the instruction occupies. Merlin and most assemblers
infer the mode from operand syntax (see the merlin-assembler skill for forcing).

| Mode | Example | Bytes | Operand resolves to |
|------|---------|-------|---------------------|
| Implied | `INX`, `RTS` | 1 | nothing (operates on a register/flag) |
| Accumulator | `ASL`, `ROR A` | 1 | the A register itself |
| Immediate | `LDA #$2A` | 2 | the literal byte in the instruction |
| Zero Page | `LDA $40` | 2 | byte at $0040 |
| Zero Page,X | `LDA $40,X` | 2 | byte at $00(40+X) — wraps within page 0 |
| Zero Page,Y | `LDX $40,Y` | 2 | byte at $00(40+Y) — only LDX/STX |
| Absolute | `LDA $1234` | 3 | byte at $1234 |
| Absolute,X | `LDA $1234,X` | 3 | byte at $1234+X |
| Absolute,Y | `LDA $1234,Y` | 3 | byte at $1234+Y |
| Indirect | `JMP ($1234)` | 3 | jump to the 16-bit pointer stored at $1234 (JMP only) |
| (Indirect,X) | `LDA ($40,X)` | 2 | pointer at $00(40+X); load from that address |
| (Indirect),Y | `LDA ($40),Y` | 2 | pointer at $0040; load from (pointer + Y) |
| Relative | `BNE label` | 2 | PC + signed 8-bit offset (branches only) |

## The two indirect indexed modes — do not confuse them

These are the workhorses of 6502 pointer code and the most common source of
porting errors.

- **`(zp,X)` — indexed indirect ("pre-indexed").** Add X to the zero-page
  address *first*, read the 16-bit pointer from `$00(zp+X)` / `$00(zp+X+1)`,
  then access that address. X selects *which pointer* from a table of pointers
  in zero page. Used less often.
- **`(zp),Y` — indirect indexed ("post-indexed").** Read the 16-bit pointer
  from `$00zp` / `$00(zp+1)` *first*, then add Y to the pointer and access.
  Y is an offset *into* the buffer the pointer names. This is the standard way
  to walk a buffer/string longer than 256 bytes. Y only — there is no `(zp),X`.

In both modes the pointer is fetched little-endian (low byte first) from zero
page, and the pointer fetch wraps within page 0.

## Page-crossing cycle penalty

`abs,X`, `abs,Y`, and `(zp),Y` reads cost **+1 cycle when the effective address
crosses a 256-byte page boundary** (i.e. when adding the index changes the high
byte). Read-modify-write and store variants do not get the penalty (they always
take the worst-case time). Branches cost +1 cycle when taken, and +1 more if the
branch target is on a different page. The opcode table lists base cycles; add
these penalties as noted.

## NMOS `JMP (indirect)` page-boundary bug

On the NMOS 6502, `JMP ($xxFF)` fetches the low byte of the target from `$xxFF`
but the high byte from `$xx00` (same page) instead of `$(xx+1)00` — the address
increment fails to carry across the page boundary. Real code sometimes avoided
placing jump vectors on a page boundary because of this. The **65C02 fixes**
this (and spends an extra cycle doing so). When porting, replicate the buggy
behavior only if the original deliberately or accidentally depended on it.

## Zero-page wrap

`zp,X` and `zp,Y` always wrap within page 0: `$FF + 1` indexes `$00`, never
`$0100`. The same is true of the pointer location arithmetic in `(zp,X)`. The
65816 with a relocated direct page behaves differently — see `65816.md`.
