# Merlin Macros, Operators, and Literal Syntax

## Macros

Define a macro between `MAC` and a terminator (`EOM` or `<<<`); call it with
`>>>`, `PMC`, or — in classic Merlin — the bare macro name in the mnemonic
field.

```
PRINT   MAC                 ; define macro PRINT
        LDA #<]1            ; ]1 = first parameter (low byte here)
        LDY #>]1            ; ]2, ]3 … up to ]8 for further parameters
        JSR COUT_STRING
        <<<                 ; end of macro (same as EOM)

        >>> PRINT;MESSAGE   ; invoke: parameters separated by ;  (or by spaces)
        PMC PRINT,MESSAGE   ; alternate invocation form
```

Macro facts:
- **Parameters `]1`..`]8`** are substituted textually at expansion. `]0`
  expands to the *number* of parameters passed — used to vary behavior by arg
  count.
- Parameters are separated by `;` (classic) or commas, depending on invocation
  form. A parameter can itself be an expression.
- Macros may be nested and may call other macros. `LUP` is often used inside a
  macro to repeat generated code.
- Because substitution is textual, a macro that defines labels needs `]`
  variable labels or `@`-labels (auto-renamed) to avoid duplicate-label errors
  when invoked more than once.

When porting, expand macros by hand first: textually substitute the arguments
for `]1`..`]n`, then read the resulting plain assembly. Don't try to reason
about the macro and the call site simultaneously.

## Expression operators

**Evaluation is strictly left to right, no precedence.** Use `{ }` to group.

| Operator | Meaning |
|----------|---------|
| `+` `-` `*` `/` | add, subtract, multiply, integer divide |
| `&` | bitwise AND |
| `.` | bitwise OR |
| `!` | bitwise EOR (XOR) |
| `-` (unary) | negate |
| `<` `=` `>` `#` | comparisons: less, equal, greater, not-equal → return 1 (true) or 0 (false) |
| `{ }` | grouping (forces algebraic order inside) |
| `*` (operand) | current program counter |

Example: `COUNT*2+1` is `((COUNT*2)+1)` only because that is also left-to-right;
`1+COUNT*2` is `(1+COUNT)*2`. Re-bracket before trusting.

## Byte-select operators (for immediate operands)

| Operator | Yields | Example |
|----------|--------|---------|
| `<expr` | low byte (bits 0–7) | `LDA #<ADDR` |
| `>expr` | high byte (bits 8–15) | `LDA #>ADDR` |
| `^expr` | bank byte (bits 16–23, 65816) | `LDA #^ADDR` |

The classic 16-bit-pointer setup idiom:
```
        LDA #<TABLE
        STA PTR
        LDA #>TABLE
        STA PTR+1
```

## Number and character literals

| Form | Meaning |
|------|---------|
| `123` | decimal |
| `$1F` | hexadecimal |
| `%1010` | binary |
| `'A'` | character, high bit **clear** |
| `"A"` | character, high bit **set** (normal Apple II text) |

## Forced addressing modes

Merlin normally picks zero-page vs absolute (and 8- vs 16-bit on 65816)
automatically from the operand value and current `MX` state. Override it:

| Syntax | Forces |
|--------|--------|
| `LDA: $11` | absolute even though `$11` fits in zero page (note the `:` after the mnemonic) |
| `LDAL $E12000` | long (24-bit) addressing — `L` suffix on the mnemonic (65816) |
| `LDA >$E12000` | long addressing via `>` prefix on the operand (65816) |

These matter when porting because they reveal the programmer's intent about
operand size — e.g. a forced-absolute access to a `$00xx` address is usually a
deliberate hardware-register or self-modifying-code access, not zero page.

## Reading checklist

1. Find the `ORG` (and `XC`/`MX` for CPU/width) to fix the context.
2. Expand macros and `LUP` loops textually.
3. Re-bracket every multi-operator expression left-to-right.
4. For each word table, check DW/DA (low-first) vs DDB (high-first).
5. Resolve `:local` labels within their global-to-global region and track
   `]variable` reassignments top to bottom.
