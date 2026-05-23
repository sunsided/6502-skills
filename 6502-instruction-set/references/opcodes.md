# NMOS 6502 Opcode / Cycle Table

Opcode bytes (hex), instruction length, and base cycle counts for the 151
documented NMOS opcodes, indexed by mnemonic × addressing mode. Use this for
disassembly (byte → instruction) and cycle-exact timing.

**Cycle annotations:**
- `+1` = add 1 cycle if the indexed effective address crosses a page boundary
  (`abs,X`, `abs,Y`, `(zp),Y` *reads* only — store/RMW forms already shown at
  worst case).
- Branches: 2 cycles not taken; **+1 if taken**, **+1 more if target crosses a
  page**.

Mode key: `imm`=#immediate, `zp`=zero page, `zpX/zpY`=zero page indexed,
`abs`=absolute, `absX/absY`=absolute indexed, `ind`=(indirect),
`Xind`=(zp,X), `indY`=(zp),Y, `A`=accumulator, `imp`=implied, `rel`=relative.

## Load / Store

| Instr | imm | zp | zpX | zpY | abs | absX | absY | Xind | indY |
|-------|-----|----|----|----|-----|------|------|------|------|
| LDA | A9 | A5 | B5 | – | AD | BD+1 | B9+1 | A1 | B1+1 |
| LDX | A2 | A6 | – | B6 | AE | – | BE+1 | – | – |
| LDY | A0 | A4 | B4 | – | AC | BC+1 | – | – | – |
| STA | – | 85 | 95 | – | 8D | 9D | 99 | 81 | 91 |
| STX | – | 86 | – | 96 | 8E | – | – | – | – |
| STY | – | 84 | 94 | – | 8C | – | – | – | – |

Cycles — loads: imm 2, zp 3, zpX/zpY 4, abs 4, absX/absY 4(+1), Xind 6, indY
5(+1). Stores: zp 3, zpX/zpY 4, abs 4, absX/absY 5, Xind 6, indY 6. Bytes: imm/zp
forms 2, abs forms 3, indirects 2.

## Arithmetic / Logic (identical mode set and timing)

| Instr | imm | zp | zpX | abs | absX | absY | Xind | indY |
|-------|-----|----|----|-----|------|------|------|------|
| ORA | 09 | 05 | 15 | 0D | 1D+1 | 19+1 | 01 | 11+1 |
| AND | 29 | 25 | 35 | 2D | 3D+1 | 39+1 | 21 | 31+1 |
| EOR | 49 | 45 | 55 | 4D | 5D+1 | 59+1 | 41 | 51+1 |
| ADC | 69 | 65 | 75 | 6D | 7D+1 | 79+1 | 61 | 71+1 |
| SBC | E9 | E5 | F5 | ED | FD+1 | F9+1 | E1 | F1+1 |
| CMP | C9 | C5 | D5 | CD | DD+1 | D9+1 | C1 | D1+1 |

Cycles: imm 2, zp 3, zpX 4, abs 4, absX/absY 4(+1), Xind 6, indY 5(+1).

## Compare X/Y, BIT

| Instr | imm | zp | abs |
|-------|-----|----|----|
| CPX | E0 (2c) | E4 (3c) | EC (4c) |
| CPY | C0 (2c) | C4 (3c) | CC (4c) |
| BIT | – | 24 (3c) | 2C (4c) |

## Read-Modify-Write (shifts, INC/DEC memory)

| Instr | A | zp | zpX | abs | absX |
|-------|---|----|----|-----|------|
| ASL | 0A | 06 | 16 | 0E | 1E |
| ROL | 2A | 26 | 36 | 2E | 3E |
| LSR | 4A | 46 | 56 | 4E | 5E |
| ROR | 6A | 66 | 76 | 6E | 7E |
| DEC | – | C6 | D6 | CE | DE |
| INC | – | E6 | F6 | EE | FE |

Cycles: A 2, zp 5, zpX 6, abs 6, absX 7. (RMW always pays worst-case timing, no
`+1`.)

## Register inc/dec and transfers (all implied, 1 byte, 2 cycles)

| INX | INY | DEX | DEY | TAX | TXA | TAY | TYA | TSX | TXS |
|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| E8  | C8  | CA  | 88  | AA  | 8A  | A8  | 98  | BA  | 9A  |

## Stack (1 byte)

| PHA | PLA | PHP | PLP |
|-----|-----|-----|-----|
| 48 (3c) | 68 (4c) | 08 (3c) | 28 (4c) |

## Jumps, calls, returns

| Instr | opcode | bytes | cycles |
|-------|--------|-------|--------|
| JMP abs | 4C | 3 | 3 |
| JMP (ind) | 6C | 3 | 5 (NMOS page-boundary bug — see addressing-modes.md) |
| JSR abs | 20 | 3 | 6 |
| RTS | 60 | 1 | 6 |
| RTI | 40 | 1 | 6 |
| BRK | 00 | 1 (skips next byte) | 7 |

## Branches (2 bytes, 2 cycles +1 taken +1 page)

| BPL | BMI | BVC | BVS | BCC | BCS | BNE | BEQ |
|-----|-----|-----|-----|-----|-----|-----|-----|
| 10  | 30  | 50  | 70  | 90  | B0  | D0  | F0  |

## Flag set/clear and NOP (1 byte, 2 cycles)

| CLC | SEC | CLI | SEI | CLV | CLD | SED | NOP |
|-----|-----|-----|-----|-----|-----|-----|-----|
| 18  | 38  | 58  | 78  | B8  | D8  | F8  | EA  |

## Decoding tips

- High nibble × low nibble: the opcode matrix has structure. Bits 1–0 of the
  opcode select the "group" (00/01/10 = control/ALU/RMW), bits 4–2 select the
  addressing mode within the group, bits 7–5 select the operation. You rarely
  need this by hand, but it explains why undocumented opcodes (gaps) behave like
  combinations of two operations.
- Any opcode byte not in these tables is **undocumented** on NMOS (see
  `undocumented.md`) and a **NOP/new instruction** on 65C02 (see `65c02.md`).
- Cycle counts above are for the NMOS 6502. The 65C02 changes a handful (decimal
  ADC/SBC +1, RMW abs,X −1, fixed `JMP (ind)` +1); the 65816 differs more
  substantially with mode-dependent operand sizes.
