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

## Installing

Each skill is a directory with a `SKILL.md`, following the [Agent Skills](https://agentskills.io)
open standard, so the same files work across Claude Code, opencode, Kilo Code,
Codex, and any other tool that implements it. You point your agent at the skill
directories; what differs per agent is *which* directory it scans.

### Quick install — `install.sh`

`install.sh` symlinks (or copies) the five `6502-*` skills into the right place:

```sh
./install.sh --claude            # Claude Code, personal      → ~/.claude/skills/
./install.sh --agents            # open standard (opencode/Kilo/Codex) → ~/.agents/skills/
./install.sh --claude --agents   # both at once
./install.sh --opencode --kilo   # each agent's own global dir
./install.sh --to PATH           # any explicit directory, e.g. a project's .claude/skills
./install.sh --agents --copy     # copy instead of symlink (Windows, or to vendor into a repo)
```

Symlink is the default, so editing a skill here updates every install. `--help`
lists all options. After installing, restart the agent; in Claude Code run
`/skills` to confirm they loaded.

### Where each agent looks

| Agent | Global (all projects) | Per project |
|-------|-----------------------|-------------|
| **Claude Code** | `~/.claude/skills/<name>/` | `<project>/.claude/skills/<name>/` |
| **opencode** | `~/.agents/skills/`, `~/.config/opencode/skills/`, `~/.claude/skills/` | `.agents/skills/`, `.opencode/skills/`, `.claude/skills/` |
| **Kilo Code** | `~/.agents/skills/`, `~/.kilo/skills/`, `~/.claude/skills/` | `.agents/skills/`, `.kilo/skills/`, `.claude/skills/` |
| **Codex** | `~/.agents/skills/` | `.agents/skills/` (cwd up to repo root) |

`.agents/skills/` is the common open-standard location read by opencode, Kilo,
and Codex; `.claude/skills/` is Claude Code's. This repo already ships an
[`.agents/skills/`](.agents/skills/) directory (symlinks to the skills at the
root), so any open-standard agent that opens this repo as a workspace picks the
skills up with no install step.

### Manual install

Without the script, copy or symlink each `6502-*` directory into one of the
locations above. For Claude Code, personal install:

```sh
for s in 6502-*/; do ln -s "$PWD/${s%/}" ~/.claude/skills/; done
```

The packaged `.skill` bundles (gitignored) are the zip form for skill
marketplaces; for direct use, install the directories as above.

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
