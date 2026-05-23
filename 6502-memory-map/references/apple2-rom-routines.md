# Apple II Monitor ROM & Applesoft Routines

These are the OS-level services a 6502 Apple II program calls with `JSR`. When
porting, treat each as a known function with defined register in/out — not as
opaque code to trace into.

## Monitor ROM entry points (`$F800-$FFFF`)

### Character / screen output

| Addr | Name | Function | Regs |
|------|------|----------|------|
| `$FDED` | COUT | output char (routes via CSW hook at `$36`) | A = char (high-bit-set ASCII) |
| `$FDF0` | COUT1 | output char to 40-col screen directly | A = char |
| `$FD8E` | CROUT | output a carriage return | — |
| `$FDDA` | PRBYTE | print A as two hex digits | A |
| `$FDE3` | PRHEX | print low nibble of A as one hex digit | A |
| `$F941` | PRNTAX | print A then X as 4 hex digits | A, X |
| `$F948` | PRBLNK | print 3 spaces | (clobbers A,X) |
| `$FB2F` / `$FC58` | INIT / HOME | text screen init / clear screen, home cursor | — |
| `$FC42` | CLREOP | clear from cursor to end of page | — |
| `$FC9C` | CLREOL | clear to end of line | — |
| `$FE80`/`$FE84` | SETINV/SETNORM | inverse / normal video for COUT | — |

### Keyboard / input

| Addr | Name | Function | Regs |
|------|------|----------|------|
| `$FD0C` | RDKEY | get one key (via KSW hook at `$38`) | returns A = char |
| `$FD1B` | KEYIN | low-level key read + random cycling | A = char |
| `$FD35` | RDCHAR | RDKEY plus escape-sequence handling | A |
| `$FD67` | GETLNZ | GETLN with leading CR | — |
| `$FD6A` | GETLN | read a line into the `$0200` buffer | returns X = length |
| `$FCA8` | WAIT | delay ≈ (26+27A+5A²)/2 cycles | A = delay count |
| `$FF3A` | BELL | output a bell char ($87) via COUT | — |
| `$FBDD` | BELL1 | actually sound the speaker beep | — |

### Misc / system

| Addr | Name | Function |
|------|------|----------|
| `$FE2C` | MOVE | block memory copy (uses `$3C-$3F`, A1/A2/A4) |
| `$FE36` | VERIFY | block compare |
| `$FE89`/`$FE93` | SETKBD/SETVID | reset KSW/CSW hooks to defaults |
| `$FF65` | MON (warm) | enter the Monitor |
| `$FF69` | MONZ | enter Monitor without resetting hooks |
| `$FF59` | reset entry | old reset/cold-ish monitor entry |

### Important Monitor zero-page locations

| Addr | Name | Meaning |
|------|------|---------|
| `$24` | CH | cursor horizontal position |
| `$25` | CV | cursor vertical position |
| `$28-$29` | BASL/BASH | base address of current text line |
| `$32` | INVFLG | video mask: $FF normal, $3F inverse, $7F flash |
| `$33` | PROMPT | input prompt character |
| `$36-$37` | CSWL/CSWH | output hook — COUT jumps here (printer/80-col redirection) |
| `$38-$39` | KSWL/KSWH | input hook — RDKEY jumps here |
| `$4E-$4F` | RNDL/RNDH | 16-bit pseudo-random seed, updated by KEYIN |

The CSW/KSW hooks are why Apple II output is so flexible: a card or routine can
patch `$36/$37` so all COUT output is redirected. When porting, a `JSR $FDED`
nominally means "print", but check whether the hooks were repointed.

## Applesoft floating-point package

Applesoft uses a 5-byte float: 1 exponent byte (excess-128, with an implied
leading mantissa bit) + 4 mantissa bytes, plus a separate sign.

| Zero page | Name | Layout |
|-----------|------|--------|
| `$9D` | FAC exponent | floating-point accumulator |
| `$9E-$A1` | FAC mantissa | 4 bytes, MSB first |
| `$A2` | FAC sign | bit 7 = sign |
| `$A5` | ARG exponent | floating-point argument register |
| `$A6-$A9` | ARG mantissa | 4 bytes |
| `$AA` | ARG sign | |

### FP entry points (Applesoft in ROM, `$E000-$F7FF`)

| Addr | Name | Function |
|------|------|----------|
| `$E7BE` | FADD | FAC = FAC + (5-byte float at addr in A/Y) |
| `$E7A7` | FSUB | FAC = mem(A/Y) − FAC |
| `$E982` | FMULT | FAC = FAC × mem(A/Y) |
| `$EA66` | FDIV | FAC = mem(A/Y) ÷ FAC |
| `$EAF9` | MOVFM | load FAC from the 5-byte float at (A/Y) |
| `$EB2B` | MOVMF | store (pack) FAC to memory at (X/Y) |
| `$EC4A` | FIN | convert ASCII string → FAC |
| `$ED34` | FOUT | convert FAC → ASCII string (at `$0100`) |
| `$ED24` | INT | FAC = INT(FAC) (floor toward −∞) |
| `$E2F2` | GIVAYF | float the signed 16-bit integer in (A=hi, Y=lo) into FAC |

Transcendental/function entries (SQR, EXP, LOG, SIN, COS, TAN, ATN, RND, ABS,
SGN) also live in the Applesoft ROM but their exact addresses vary slightly by
ROM revision — verify against the specific ROM (the "Applesoft Internals" /
S-C documentor listings) before hard-coding them.

## Applesoft runtime zero page

| Addr | Name | Meaning |
|------|------|---------|
| `$67-$68` | TXTTAB | start of BASIC program text (`$0801` default) |
| `$69-$6A` | VARTAB | start of simple variables |
| `$6B-$6C` | ARYTAB | start of arrays |
| `$6D-$6E` | STREND | end of arrays / start of free space |
| `$6F-$70` | FRETOP | bottom of string space (grows down) |
| `$73-$74` | MEMSIZ | HIMEM, top of string space |
| `$B1-$C8` | CHRGET | self-modifying routine that fetches the next BASIC token |
| `$B8-$B9` | TXTPTR | pointer into the BASIC program (used by CHRGET) |

`CHRGET` (`JSR $00B1`) advances `TXTPTR` and returns the next non-space program
byte in A, setting C/Z for digit/terminator tests — the heart of the Applesoft
interpreter loop. `CHRGOT` (`$00B7`) re-fetches the current byte without
advancing.
