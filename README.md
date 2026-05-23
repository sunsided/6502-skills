# 6502 Skills

A cluster of Claude skills for working with **6502-family assembly** — reading,
writing, understanding, and porting it — with a focus on the Apple II (Merlin
assembler), the Commodore 64, and the Atari 400/800/XL/XE. All skills share a
`6502-` prefix so they group together once installed.

## The skills

| Skill | What it covers |
|-------|----------------|
| **`6502-instruction-set`** | NMOS 6502 / 65C02 / 65816 mnemonics, addressing modes, opcode bytes, cycle counts, and exact flag semantics. CPU-variant notes (6510/C64, 2A03/NES). The reference for *what an instruction does*. |
| **`6502-merlin-assembler`** | Merlin macro-assembler source: column layout, directives (DFB/DW/DDB/DCI/ASC/HEX/LUP/MAC…), macros and parameters, label/variable conventions, and Merlin's left-to-right expression evaluation. Apple Merlin 8/16/32 and Commodore Merlin 64/128. |
| **`6502-memory-map`** | Apple II, C64, and Atari 8-bit memory maps, I/O registers, ROM entry points, and zero-page conventions: Apple soft switches, language card, Monitor ROM, Applesoft FP; C64 6510 banking, VIC-II/SID/CIA, the KERNAL jump table; Atari ANTIC/GTIA/POKEY, shadow registers, CIO/SIO, the $E450 vectors. |
| **`6502-sweet16`** | Wozniak's SWEET16 — the 16-bit interpreted pseudo-processor in the Apple II Integer BASIC ROM (entry `$F689`): registers, opcode set, invocation, and how to decode its inline bytecode. |
| **`6502-to-rust`** | A two-stage workflow for porting 6502 assembly to idiomatic Rust via an explicit, flag-faithful intermediate language: lift → recover intent → emit, plus correctness rules and a verification method. |

## How they fit together

```
            6502-instruction-set   ← semantics of every instruction
                     │
 6502-merlin-assembler   6502-memory-map   6502-sweet16
   (source dialect)      (what addresses     (the inline VM)
                          mean per platform)
                     │
                6502-to-rust        ← uses all of the above to port
```

When porting (`6502-to-rust`), the other skills supply the context the port
depends on: the instruction set fixes semantics, the memory map classifies every
address as RAM / hardware / ROM call, the Merlin skill decodes the source, and
SWEET16 handles any inline-bytecode regions.

## Layout

Each skill is a directory with a `SKILL.md` (the always-loaded instructions and
trigger description) and a `references/` folder of detail files loaded only when
needed (progressive disclosure). See each `SKILL.md` for the reference index.

## Authoring

Built and iterated with the `skill-creator` skill. Key technical facts
(SWEET16 encodings, Merlin directives, ROM routine addresses, C64 hardware maps)
were verified against primary sources (Wozniak's BYTE 1977 SWEET16 article, the
Brutal Deluxe Merlin 32 manual, the Apple II/C64 memory-map references) during
authoring.
