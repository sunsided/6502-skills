---
name: 6502-sweet16
description: >-
  Reference for SWEET16, Steve Wozniak's 16-bit interpreted pseudo-processor
  built into the Apple II Integer BASIC ROM (entry $F689). SWEET16 is a tiny
  virtual machine with sixteen 16-bit registers (R0-R15) living in zero page,
  invoked by JSR SWEET16 followed by inline bytecode and terminated by RTN.
  Use this skill WHENEVER you see a JSR $F689 (or JSR SWEET16) followed by data
  bytes, encounter SWEET16 mnemonics (SET, LDD, STD, POP, STP, CPR, BNC, RTN,
  BS/RS), need to disassemble or trace SWEET16 bytecode, or are porting Apple II
  code that drops into SWEET16 for compact 16-bit pointer math and block moves.
  Trigger on "what is SWEET16", "$F689", inline bytecode after a JSR, or 16-bit
  register ops like "SET R1" / "LDD @R1". Pairs with the 6502-instruction-set,
  6502-memory-map, and 6502-to-rust skills.
---

# SWEET16 — Wozniak's 16-bit Pseudo-Processor

SWEET16 is a 512-byte interpreter in the Apple II Integer BASIC ROM that gives
the 8-bit 6502 a compact **16-bit instruction set**. Woz wrote it to shrink the
16-bit pointer arithmetic in Apple BASIC (incrementing pointers, comparing
addresses, block moves) — operations that are verbose in native 6502. It trades
speed (≈10× slower, it's interpreted) for code density. You will meet it in
Integer BASIC-era Apple II code and in anything that calls `$F689`.

## How it is invoked — the key idea

SWEET16 is entered with an ordinary `JSR SWEET16` (`JSR $F689` on the Apple II).
**The bytes immediately following the JSR are not 6502 code — they are SWEET16
bytecode**, executed by the interpreter. A `RTN` opcode (`$00`) ends SWEET16
mode and returns to the 6502 instruction right after the bytecode.

```
        JSR  SWEET16     ; $F689 — switch into the VM
        ; ---- the following bytes are SWEET16 bytecode, NOT 6502 ----
        11 00 20         ; SET R1, $2000     (1n + 2 immediate bytes, low first)
        12 00 40         ; SET R2, $4000
        13 00 01         ; SET R3, $0100     (count)
LOOP    41               ; LD  @R1           (R0 = (R1), R1++)
        52               ; ST  @R2           ((R2) = R0, R2++)
        F3               ; DCR R3
        07 ??            ; BNZ LOOP
        00               ; RTN — back to 6502
        ; ---- 6502 resumes here ----
```

**Disassembly trap:** a 6502 disassembler will mis-decode the bytecode region as
6502 instructions. Whenever you see `JSR $F689`, switch to SWEET16 decoding
until the `$00` (RTN). This is the single most common mistake reading this code.

## The 16 registers (in zero page `$00-$1F`)

Each register is a 16-bit little-endian pair. Four are special:

| Register | ZP addr | Role |
|----------|---------|------|
| R0 | `$00-$01` | **accumulator (ACC)** — implicit operand of ADD/SUB/LD/ST |
| R1-R11 | `$02-$17` | general purpose |
| R12 | `$18-$19` | subroutine return-stack pointer (used by BS/RS) |
| R13 | `$1A-$1B` | holds the result of the last CPR (compare) |
| R14 | `$1C-$1D` | status register (drives the branch tests) |
| R15 | `$1E-$1F` | program counter (the SWEET16 PC) |

Because the registers are just zero-page locations, 6502 code and SWEET16 code
share them — you can set up a pointer in zero page before entry and it *is* the
corresponding Rn.

## Opcode set

### Register operations — high nibble `1`–`F`, low nibble = register `n`

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| `1n` | SET Rn | Rn ← next two bytes (low byte first) |
| `2n` | LD Rn | R0 ← Rn |
| `3n` | ST Rn | Rn ← R0 |
| `4n` | LD @Rn | R0 ← byte at (Rn); then Rn ← Rn + 1 (high byte of R0 = 0) |
| `5n` | ST @Rn | byte at (Rn) ← low byte of R0; then Rn ← Rn + 1 |
| `6n` | LDD @Rn | R0 ← word at (Rn); then Rn ← Rn + 2 |
| `7n` | STD @Rn | word at (Rn) ← R0; then Rn ← Rn + 2 |
| `8n` | POP @Rn | Rn ← Rn − 1; then R0 ← byte at (Rn) (high byte of R0 = 0) |
| `9n` | STP @Rn | Rn ← Rn − 1; then byte at (Rn) ← low byte of R0 |
| `An` | ADD Rn | R0 ← R0 + Rn (carry → R14) |
| `Bn` | SUB Rn | R0 ← R0 − Rn (carry/borrow → R14) |
| `Cn` | POPD @Rn | Rn ← Rn − 2; then R0 ← word at (Rn) |
| `Dn` | CPR Rn | R13 ← R0 − Rn (compare; sets status, doesn't change R0) |
| `En` | INR Rn | Rn ← Rn + 1 |
| `Fn` | DCR Rn | Rn ← Rn − 1 |

The `@Rn` modes auto-increment (LD/ST/LDD/STD) or pre-decrement (POP/STP/POPD)
the pointer register — that is what makes SWEET16 so compact for walking buffers
and implementing stacks. Byte loads zero-extend into R0's high byte.

### Non-register operations — high nibble `0`, low nibble selects

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| `00` | RTN | exit SWEET16, return to 6502 (restores 6502 registers) |
| `01 dd` | BR | branch always (signed 8-bit displacement `dd`) |
| `02 dd` | BNC | branch if no carry |
| `03 dd` | BC | branch if carry |
| `04 dd` | BP | branch if plus (R0/last result positive, bit 15 = 0) |
| `05 dd` | BM | branch if minus (bit 15 = 1) |
| `06 dd` | BZ | branch if zero |
| `07 dd` | BNZ | branch if nonzero |
| `08 dd` | BM1 | branch if result = `$FFFF` (minus one) |
| `09 dd` | BNM1 | branch if result ≠ `$FFFF` |
| `0A` | BK | execute a 6502 BRK |
| `0B` | RS | return from a SWEET16 subroutine (pops via R12) |
| `0C dd` | BS | call a SWEET16 subroutine (pushes via R12, then branches) |
| `0D`–`0F` | (unused) | not defined |

Branch displacements are a signed byte relative to the address of the byte
*after* the displacement (like 6502 relative branches).

## Branch/status semantics

The branch conditions read the status register R14, which is updated by the
last register operation that produced a result in R0 (LD, ADD, SUB, INR, DCR,
LD/POP @Rn…) or by CPR (which puts its result in R13 and sets status from it):

- **BZ / BNZ** — zero / nonzero result.
- **BP / BM** — bit 15 of the result clear / set (treat as sign).
- **BM1 / BNM1** — result is exactly `$FFFF` / not. Handy as a loop sentinel.
- **BC / BNC** — carry out of the last ADD/SUB (16-bit), i.e. unsigned overflow
  / borrow. After `CPR`, carry reflects an unsigned comparison of R0 vs Rn.

A typical compare-and-branch: `CPR Rn` (Dn) then `BC`/`BNC`/`BZ` to test the
relationship between R0 and Rn.

## Porting SWEET16 to Rust (see the 6502-to-rust skill)

SWEET16 is pleasant to port because it is already higher-level than 6502:
- Model the 16 registers as `[u16; 16]` (or named fields), with R0 the accumulator.
- `@Rn` loads/stores become indexed memory access with an explicit `Rn += 1/2`.
- ADD/SUB are `u16` wrapping ops; capture the carry into a `bool` (the R14
  status) so BC/BNC port correctly.
- BP/BM test `(result & 0x8000) != 0`; BM1/BNM1 test `result == 0xFFFF`.
- BS/RS are a call/return using R12 as a stack pointer into memory — port them
  as a recursion or an explicit stack, matching the original.

Decode the inline bytecode into a list of SWEET16 instructions first, then port
that list — never try to port the raw bytes as if they were 6502.

## Source / verification

Entry point `$F689`, register roles, and the full opcode map are per Wozniak's
"SWEET16: The 6502 Dream Machine" (BYTE, Nov 1977) and the 6502.org SWEET16
listing. Reimplementations exist for other 6502 systems; the bytecode is
platform-neutral, but the `$F689` entry is Apple II Integer-BASIC-ROM specific —
on other systems SWEET16 is linked in at a different address.
