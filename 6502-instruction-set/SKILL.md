---
name: 6502-instruction-set
description: >-
  Reference and semantics for the MOS 6502 / 65C02 / 65816 instruction set:
  mnemonics, addressing modes, opcode bytes, cycle counts, and exact flag
  effects. Use this skill WHENEVER you read, write, disassemble, trace, explain,
  or port 6502-family assembly (including Apple II, Commodore, NES, Atari, BBC
  Micro code), or when you need to know what an instruction does to the
  registers, status flags, or memory. Trigger on questions like "what does this
  6502 routine do", "what flags does ADC set", "is this a 65C02 instruction",
  "trace this assembly", or any opcode/mnemonic (LDA, STA, JSR, ROL, BIT, SWEET16
  excepted) appearing in a file. Pairs with the 6502-merlin-assembler,
  6502-memory-map, and 6502-to-rust skills.
---

# 6502 / 65C02 / 65816 Instruction Set

Use this to reason about the *semantics* of 6502-family code: what each
instruction does to the A/X/Y registers, the processor status flags, the stack,
and memory. Getting flag behavior right is the single most error-prone part of
reading or porting 6502 code — most subtle bugs in ports come from a misread of
carry, overflow, or the BCD decimal mode.

## CPU model: registers and status flags

```
A   8-bit  Accumulator         — the only register with full ALU
X   8-bit  Index register X    — indexing, loop counters, stack via TSX/TXS
Y   8-bit  Index register Y    — indexing (note: only Y works with (zp),Y)
S   8-bit  Stack pointer       — stack lives at $0100 + S, grows downward
PC  16-bit Program counter
P   8-bit  Processor status    — flags below
```

Status register `P`, bit 7 → 0: `N V - B D I Z C`

| Flag | Bit | Name      | Meaning |
|------|-----|-----------|---------|
| N    | 7   | Negative  | = bit 7 of the last result |
| V    | 6   | Overflow  | signed overflow from ADC/SBC; or bit 6 of operand for BIT |
| -    | 5   | (unused)  | reads as 1 |
| B    | 4   | Break     | set in the copy of P pushed by BRK/PHP; not a real bit |
| D    | 3   | Decimal   | when set, ADC/SBC operate in BCD (binary-coded decimal) |
| I    | 2   | IRQ disable | when set, maskable interrupts are ignored |
| Z    | 1   | Zero      | set when the last result was $00 |
| C    | 0   | Carry     | carry out of ADC / borrow-complement for SBC / shifted bit / compare result |

The two flags people get wrong:
- **Carry on subtraction/compare is *inverted borrow*.** `SBC` computes `A + (~M) + C`; you must `SEC` (C=1) before a standalone subtraction. After `CMP`, carry is set when `A >= operand` (unsigned), cleared otherwise.
- **`BIT` does not load the operand into anything.** It sets Z from `A AND M`, but copies bit 7 of *memory* into N and bit 6 of *memory* into V — independent of A.

## CPU variants you'll meet in the wild

The *instruction set* is shared; the differences below are mostly about what's
bolted on around the core. The base 6502 references apply to all of them.

| Chip | Used in | Relationship to base 6502 |
|------|---------|---------------------------|
| 6502 | Apple II/II+/IIe, Atari 8-bit, BBC Micro | the baseline |
| 6510 | Commodore 64 | 6502 + on-chip 6-bit I/O port at `$0000/$0001` that banks ROM/RAM in/out; instruction set identical (banking detail lives in the platform-memory-map skill) |
| 8502 | Commodore 128 | 6510-like, faster clock |
| 2A03 / 2A07 | NES / Famicom | 6502 core with **decimal mode disabled** (ADC/SBC ignore D); has integrated audio |
| 65C02 | Apple IIe-enhanced, IIc | CMOS superset — see `references/65c02.md` |
| 65802 / 65816 | Apple IIgs | 16-bit superset — see `references/65816.md` |

The NES's missing BCD is a real porting trap: NES code never relies on decimal
mode, so a `SED`/`CLD` you'd expect is simply absent, and any stray `D=1` would
be a no-op there but not on a C64 or Apple II.

## How to read the references

Start here; drop into a reference file only when you need the detail:

- **`references/semantics.md`** — every base mnemonic with its operation in
  pseudocode and exactly which flags it touches. This is the file to read when
  porting or tracing. Read it whenever flag behavior matters.
- **`references/addressing-modes.md`** — the 13 NMOS addressing modes, their
  syntax, how operand bytes are fetched, the page-crossing cycle penalty, and
  the NMOS `JMP (ind)` page-boundary bug.
- **`references/opcodes.md`** — the opcode-byte / bytes / cycles table indexed by
  mnemonic × addressing mode. Read it when you are disassembling raw bytes or
  need cycle-exact timing.
- **`references/65c02.md`** — what the CMOS 65C02 adds and changes vs NMOS
  (new instructions, new addressing modes, bug fixes). Apple IIe-enhanced/IIc.
- **`references/65816.md`** — the 16-bit 65816/65802 (Apple IIgs): native vs
  emulation mode, 8/16-bit M/X flags, wider registers, bank registers, long
  addressing, block moves. Read this before touching any IIgs source.
- **`references/undocumented.md`** — NMOS "illegal" opcodes (LAX, SAX, DCP, ISC,
  SLO, RLA, SRE, RRA, ANC, ALR, ARR, etc.). Some real Apple II / C64 code
  relies on these; the 65C02 redefines them as NOPs.

## Reading workflow

When handed a block of 6502 assembly:
1. Identify the CPU variant. If you see `STZ`, `BRA`, `PHX`, `(zp)` indirect, or
   the file targets a IIe-enhanced/IIc, assume 65C02. If you see `REP`/`SEP`,
   `MX`, `.al`, long addresses, or a IIgs target, assume 65816 — the operand
   *width* of immediate loads then depends on the M/X flag state, so you must
   track mode.
2. Track the flags as a small state machine. Annotate each branch with the
   condition that reaches it (`BCS` = carry set = unsigned `>=` after CMP, etc.).
3. Watch for decimal mode: a `SED` far from the `ADC`/`SBC` it affects changes
   the arithmetic. Always pair it mentally with the matching `CLD`.
4. Self-modifying code and computed jumps are common and idiomatic on this
   platform — do not assume code is immutable.

## Branch condition cheat-sheet

| Instr | Taken when | Typical meaning after CMP A,M |
|-------|-----------|-------------------------------|
| BEQ / BNE | Z=1 / Z=0 | A == M / A != M |
| BCS / BCC | C=1 / C=0 | A >= M / A < M  (unsigned) |
| BMI / BPL | N=1 / N=0 | result bit 7 set / clear |
| BVS / BVC | V=1 / V=0 | signed overflow occurred / not |

For *signed* comparison the idiom is more involved (it combines N and V); see
`references/semantics.md` under CMP for the canonical signed-compare pattern.
