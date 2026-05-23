# Undocumented ("illegal") NMOS 6502 opcodes

The NMOS 6502 leaves 105 opcodes officially unused, but most do something
deterministic (a side effect of how the instruction decoder reuses control
lines). Real Apple II, C64, and demoscene code sometimes uses the stable ones
for speed/size. The **65C02 redefines all of these as NOPs** (of 1–3 bytes), so
code relying on them breaks on a 65C02. Treat their presence as a strong signal
the target is an NMOS part.

## Stable, commonly used combos

These combine two documented operations on the same operand fetch:

| Mnemonic(s) | Operation | Flags |
|-------------|-----------|-------|
| LAX | A <- M; X <- M (LDA + LDX together) | N Z |
| SAX (AXS, AAX) | M <- A & X (store, no flag change) | — |
| DCP (DCM) | M <- M-1; then CMP A with M | N Z C |
| ISC (ISB, INS) | M <- M+1; then SBC | N V Z C |
| SLO (ASO) | M <- M<<1; then ORA | N Z C |
| RLA | M <- ROL M; then AND | N Z C |
| SRE (LSE) | M <- M>>1; then EOR | N Z C |
| RRA | M <- ROR M; then ADC | N V Z C |

## Immediate / accumulator combos

| Mnemonic(s) | Operation | Flags |
|-------------|-----------|-------|
| ANC #imm | A <- A & imm; C <- bit 7 of result | N Z C |
| ALR (ASR) #imm | A <- (A & imm) >> 1 | N Z C |
| ARR #imm | A <- (A & imm) ROR 1, with unusual C/V semantics | N V Z C |
| SBX (AXS, SAX) #imm | X <- (A & X) - imm (no borrow in) | N Z C |

`ARR`'s carry and overflow follow odd rules (and differ in decimal mode); verify
against a per-bit reference if a port depends on it.

## Unstable opcodes — avoid relying on these

Their result depends on analog effects, temperature, or the data bus and is not
reliably reproducible:

- **XAA (ANE) #imm** — `A <- (A | magic) & X & imm`, "magic" is unstable.
- **LAX #imm** — unstable form of LAX with immediate.
- **SHA / SHX / SHY / TAS (SHS, XAS)** — stores of `reg & (high-byte-of-addr+1)`;
  the value written is corrupted when the index crosses a page.

## Jam / lock-up

- **KIL (JAM, HLT)** — opcodes `$02 $12 $22 …` halt the CPU until reset.

## Practical guidance for porting

1. If you see one of the stable combos, port it as the two-step equivalent
   (e.g. `DCP $40` → decrement `[$40]`, then compare A to it, updating N/Z/C).
2. If you see an unstable opcode in production code, it is almost certainly a
   misdisassembly — re-check the byte boundaries and the CPU variant before
   trusting it.
3. Multi-byte NOPs (`$80 #imm`, `$0C abs`, etc.) are sometimes used as
   instruction-skipping tricks (a branch lands past a 1-byte op that the
   fall-through path "executes" as the immediate operand of a NOP). Watch for
   this when control flow seems to enter mid-instruction.
