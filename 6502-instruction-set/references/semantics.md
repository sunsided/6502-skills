# 6502 Instruction Semantics and Flag Effects

Every base (NMOS) mnemonic, what it does, and exactly which flags it affects.
Notation: `A` `X` `Y` registers; `M` the operand (memory or immediate); `C` the
carry flag; `[addr]` memory contents; `<-` assignment. "Flags: N Z" means only
N and Z are updated; all others are preserved.

Flag set rule for almost every data op: **N = bit 7 of the result, Z = (result
== 0)**. Stated as "N Z (from result)" below.

## Load / Store

| Instr | Operation | Flags |
|-------|-----------|-------|
| LDA | A <- M | N Z |
| LDX | X <- M | N Z |
| LDY | Y <- M | N Z |
| STA | M <- A | — |
| STX | M <- X | — |
| STY | M <- Y | — |

## Register transfers

| Instr | Operation | Flags |
|-------|-----------|-------|
| TAX | X <- A | N Z |
| TAY | Y <- A | N Z |
| TXA | A <- X | N Z |
| TYA | A <- Y | N Z |
| TSX | X <- S | N Z |
| TXS | S <- X | — (TXS sets NO flags — common trap) |

## Stack

Stack is at `$0100 + S`, descending. Push writes then decrements S; pull
increments S then reads.

| Instr | Operation | Flags |
|-------|-----------|-------|
| PHA | push A | — |
| PLA | A <- pull | N Z |
| PHP | push P (with B=1, bit5=1) | — |
| PLP | P <- pull | all (restores every flag) |

## Logical

| Instr | Operation | Flags |
|-------|-----------|-------|
| AND | A <- A & M | N Z |
| ORA | A <- A \| M | N Z |
| EOR | A <- A ^ M | N Z |
| BIT | Z <- (A & M)==0; N <- bit7 of M; V <- bit6 of M | N V Z |

`BIT` is special: A is unchanged, and N/V come from the *memory* operand's top
two bits, not from the AND result. It is used both to test bits of A against a
mask (the Z result) and to sample bits 7/6 of a hardware/status byte (the N/V
results) in a single instruction.

## Arithmetic

| Instr | Operation | Flags |
|-------|-----------|-------|
| ADC | A <- A + M + C | N V Z C |
| SBC | A <- A + (~M) + C  (i.e. A - M - (1-C)) | N V Z C |

- **ADC**: C is carry-out of bit 7 (unsigned overflow). V is signed overflow:
  set when the signed result doesn't fit in -128..127, computed as
  `(A^result) & (M^result) & 0x80`.
- **SBC**: set carry first (`SEC`) for a plain subtract. Borrow occurred when C
  is *clear* afterward. V is signed overflow of the subtraction.
- **Decimal mode (D=1)**: ADC/SBC treat operands as two BCD digits per byte and
  produce a BCD result; C is the decimal carry. On NMOS the N/V/Z flags are
  *undefined/garbage* in decimal mode (only C is meaningful); the 65C02 fixes
  them and adds a cycle. When porting, find the surrounding `SED`/`CLD` to know
  whether a given ADC/SBC is binary or BCD.

## Compare (subtract without storing)

| Instr | Operation (computes reg - M, discards result) | Flags |
|-------|-----------------------------------------------|-------|
| CMP | A - M | N Z C |
| CPX | X - M | N Z C |
| CPY | Y - M | N Z C |

After a compare: **C set ⇔ reg >= M (unsigned)**; Z set ⇔ equal; N = bit 7 of
the (reg - M) result. V is *not* affected, which is why signed comparison needs
extra work. Decimal mode does **not** affect compares.

**Signed compare idiom.** After `CMP`/`CPX`/`CPY`, a signed `>=` test is
`BPL`/`BMI` only if no overflow; the robust pattern is:
```
        SEC
        SBC  operand     ; or CMP then read N,V
        BVC  *+4
        EOR  #$80        ; flip N so it reflects the true sign of the difference
        BMI  less_than   ; signed reg < operand
        ; else reg >= operand
```
i.e. signed `<` is taken when `N XOR V == 1`.

## Increment / Decrement

| Instr | Operation | Flags |
|-------|-----------|-------|
| INC | M <- M + 1 | N Z |
| DEC | M <- M - 1 | N Z |
| INX | X <- X + 1 | N Z |
| INY | Y <- Y + 1 | N Z |
| DEX | X <- X - 1 | N Z |
| DEY | Y <- Y - 1 | N Z |

All wrap modulo 256 and do **not** touch carry. (NMOS has no INC A / DEC A; the
65C02 adds them.)

## Shifts and rotates

| Instr | Operation | Flags |
|-------|-----------|-------|
| ASL | C <- bit7; result = M << 1 (bit0 <- 0) | N Z C |
| LSR | C <- bit0; result = M >> 1 (bit7 <- 0) | N Z C |
| ROL | new = (M << 1) \| old_C; C <- old bit7 | N Z C |
| ROR | new = (M >> 1) \| (old_C << 7); C <- old bit0 | N Z C |

Operate on A (accumulator mode) or on memory. Multi-byte shifts chain through
carry: shift/rotate the low byte first, then `ROL`/`ROR` the higher bytes.

## Jumps and subroutines

| Instr | Operation | Flags |
|-------|-----------|-------|
| JMP | PC <- target (absolute or indirect) | — |
| JSR | push (PC+2 high, then low); PC <- target | — |
| RTS | PC <- (pull low, pull high) + 1 | — |

`JSR` pushes the address of its *last byte* (return - 1); `RTS` pulls and adds 1.
This `RTS`-minus-one quirk is exploited by the "RTS trampoline" idiom: push a
target address minus one, then `RTS` to jump to it (computed jump / jump table).

## Branches (relative, signed 8-bit offset, no flags affected)

| Instr | Taken when |
|-------|-----------|
| BCC / BCS | C=0 / C=1 |
| BNE / BEQ | Z=0 / Z=1 |
| BPL / BMI | N=0 / N=1 |
| BVC / BVS | V=0 / V=1 |

Range is -128..+127 from the instruction following the branch. Out-of-range
needs an inverted branch over a `JMP`.

## Flag instructions

| Instr | Effect |
|-------|--------|
| CLC / SEC | C <- 0 / 1 |
| CLD / SED | D <- 0 / 1 (decimal mode) |
| CLI / SEI | I <- 0 / 1 (IRQ enable / disable) |
| CLV | V <- 0 (there is no SEV) |

## System / interrupts

| Instr | Operation | Flags |
|-------|-----------|-------|
| BRK | push PC+2, push P (B=1), set I, PC <- ($FFFE) IRQ vector | I set |
| RTI | pull P, pull PC (no +1, unlike RTS) | all (from pulled P) |
| NOP | do nothing | — |

`BRK` is a 1-byte opcode but the pushed return address skips the *next* byte —
so `BRK` is effectively a 2-byte instruction; the byte after it is a signature
byte the handler can read. `RTI` pulls the full processor status and the exact
PC (no off-by-one), distinguishing it from `RTS`.

Interrupt vectors (top of memory): NMI `$FFFA/B`, RESET `$FFFC/D`, IRQ/BRK
`$FFFE/F`. IRQ and BRK share a vector; the handler tests the B flag in the
pushed status byte to tell them apart.
