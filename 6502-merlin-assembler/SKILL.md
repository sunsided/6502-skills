---
name: 6502-merlin-assembler
description: >-
  How to read and write 6502/65C02/65816 assembly source for the Merlin macro
  assembler (Merlin 8, Merlin Pro, Merlin 16/16+, Merlin 32 on Apple II/IIgs,
  and Merlin 64/128 on Commodore). Covers Merlin's source column layout, its
  pseudo-opcodes/directives (ORG, EQU, DFB, DW, DDB, DCI, ASC, HEX, DS, LUP,
  DO/FIN, MAC/EOM), the macro system and parameters (]1..]8), label and variable
  conventions (:local, ]var), expression operators and Merlin's left-to-right
  evaluation, the low/high/bank byte-select operators, and forced addressing.
  Use this skill WHENEVER you encounter, write, or port Merlin-format assembly
  source, see Merlin directives like DFB/DCI/LUP/MAC/EOM/PUT, see labels like
  ]LOOP or :SKIP, or need to understand a .S Merlin listing. Especially trigger
  when the user mentions Merlin, or asks why an assembler expression evaluates
  oddly (left-to-right!), or how a macro expands. Pairs with the
  6502-instruction-set, 6502-memory-map, and 6502-to-rust skills.
---

# Merlin Macro Assembler

Merlin (by Glen Bredon) is the dominant 6502-family assembler on the Apple II
and a notable one on the Commodore 64/128. Merlin 32 is a modern cross-platform
re-implementation (Brutal Deluxe) that assembles classic source. Its syntax has
quirks that will mislead you if you read it like a modern assembler — most
importantly, **expressions evaluate strictly left-to-right with no operator
precedence**.

## Source line layout

Merlin source is column/field oriented, not free-form. Each line is:

```
LABEL   MNEMONIC   OPERAND        ; comment
```

```
* A full-line comment starts with * in column 1 (or ;)
START   LDA #$00         ; load zero        — label in col 1, ; comment
        STA COUNT
]LOOP   INC COUNT        ; ]LOOP is a variable label (reassignable)
        LDA COUNT
        CMP #10
        BCC ]LOOP
:DONE   RTS              ; :DONE is a local label (scoped to this region)
COUNT   DS 1             ; reserve 1 byte
```

Rules that trip up readers:
- A symbol in **column 1** is a label definition. Whitespace then mnemonic.
- `*` in column 1 = whole-line comment. `;` = comment to end of line anywhere.
- Three label kinds:
  - **Global**: ordinary names, case-sensitive, visible everywhere.
  - **Local `:NAME`**: valid only between the two surrounding global labels —
    lets you reuse `:LOOP`, `:DONE` etc. in every subroutine without clashing.
  - **Variable `]NAME`**: can be reassigned with `]NAME = expr`; used heavily in
    macros and `LUP` loops. (Merlin 32 additionally treats a bare `]NAME` as a
    backward-only local; the classic mental model — "`:` = local label, `]` =
    reassignable variable" — is the safe one to read by.)
- `*` in an **operand** means "the current program counter" (e.g. `BNE *+4`).

## The one thing to remember: left-to-right evaluation

`LDA #1+2*3` loads **9**, not 7. Merlin applies operators strictly left to
right with no precedence. Use braces `{ }` for algebraic grouping: `{1+2*3}` =
7. Every time you read or port a non-trivial Merlin expression, re-parenthesize
it left-to-right in your head before trusting it.

## How to read the references

- **`references/directives.md`** — every pseudo-opcode/directive: data (DFB, DW,
  DA, DDB, ADR, ADRL), strings (ASC, DCI, INV, FLS, REV, STR), storage (DS,
  HEX), control (LUP, DO/IF/ELSE/FIN, ERR, END), files (PUT, USE, SAV, DSK),
  and the 65816/IIgs segment directives. Read it to know what bytes a directive
  emits and its exact byte order. **DW/DA = low byte first; DDB = high byte
  first** — a frequent porting bug.
- **`references/macros-and-syntax.md`** — the macro system (MAC ... EOM/`<<<`,
  invocation via `>>>`/PMC/bare name, parameters `]1`..`]8`, `]0` = arg count),
  the full operator set, number/char literal formats, the `<`/`>`/`^`
  byte-select operators, and forced addressing-mode syntax. Read it when
  expanding a macro by hand or decoding an operator-heavy expression.

## Version differences worth knowing

- **Merlin 8 / Merlin Pro**: 8-bit Apple II (6502/65C02). Core directives only.
- **Merlin 16 / 16+**: adds 65816 and IIgs support, `MX`, long data directives.
- **Merlin 32**: modern cross-assembler; default ORG `$8000`; adds segment/OMF
  directives (`REL`, `TYP`, `KND`, `SNA`…) for IIgs executables and `PUTBIN`.
- **Merlin 64/128**: Commodore variants; same core directive language.

If a directive in the source isn't in `directives.md`, it's almost certainly a
later-version (Merlin 16/32) or segment/linker directive — check the bottom of
that file before assuming it's a macro.
