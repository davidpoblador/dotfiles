---
name: ast-grep-rewrite
description: Rewrite code structurally across many files in one command. Use when renaming a function, class or variable across files, changing a call signature at every call site, removing every use of an argument, decorator or call, or making any other edit that repeats across more than a handful of sites, instead of a series of per-file sed, perl or Edit calls. Covers `ast-grep run --rewrite -U`, YAML rules with `fix:` and `transform`, and verifying the result with the formatter and type checker.
---

# Structural rewrites with ast-grep

One `ast-grep` command replaces every site of a repeated edit at once: 33 call
sites in 13 files take about 0.05 s, against one tool call per file through
Edit. It matches syntax nodes, so it never touches strings, comments or parts
of longer identifiers, and it handles multi-line arguments that a regex would
have to spell out.

The `ast-grep:ast-grep` skill teaches writing rules to **find** code. This one
covers **changing** it. Use the CLI through Bash: the ast-grep MCP server is
search-only.

## The loop

1. **Preview.** Run the command without `-U`; it prints a diff and changes
   nothing. Check the sites it hits, and the ones it should hit and doesn't.
2. **Apply.** Rerun with `-U` (`--update-all`). Never use `--interactive`: it
   waits for keystrokes an agent can't send.
3. **Review** with `git diff`.
4. **Format, then type check**, with the project's own recipes where it has
   them (`just fmt`, `just lint`), otherwise `ruff format .` and the type
   checker through the project's environment (`uv run ty check`). Run the
   formatter in fix mode, not only `--check`: rewrites can leave stray spaces
   or reflow a call onto fewer lines.

Exit codes tell you about misses, which is what perl and sed never do:

- `ast-grep run` exits 1 when the pattern matches nothing, with or without
  `-U`.
- `ast-grep scan` exits 0 even when no rule matched. Check that it printed
  `Applied N changes`, or that `--json=compact` returned more than `[]`.

## Patterns

`$NAME` matches exactly one node (one expression, one argument). `$$$NAME`
matches any number of nodes, including none. A metavariable used in the
rewrite inserts whatever it matched.

### Rename

```bash
ast-grep run --lang python -p load -r fetch -U .
```

A bare identifier pattern is **not scope-aware**. It renames every identifier
spelled `load`: the definition, imports and calls, but also methods of
unrelated classes (`Store.load`), attributes (`mod.load`) and keyword-argument
names (`dict(load=1)`). Use it for names distinctive enough that every hit is
the same symbol, and check the preview against `findReferences` when an LSP is
available. Strings, comments and Markdown docs are left alone, so docs need a
separate `rg` and `sed` pass.

To rename only calls to a plain name, match the identifier in a call's function
position with a YAML rule (see *YAML rules* below):

```yaml
id: rename-load-calls
language: python
rule:
  kind: identifier
  regex: ^load$
  inside:
    kind: call
    field: function
fix: fetch
```

That changes `load(...)` and leaves `mod.load(...)`, `Store().load()`, the
import and the `def` alone. Rename those separately; the type checker reports
any import you missed.

### Change a call signature

```bash
ast-grep run --lang python -p 'connect($U)' -r 'connect(url=$U)' -U .
```

`$U` matches calls with exactly one argument, so calls with more are not
touched. Change the `def` separately. `$U` captures the argument without its
trailing comma, so a call split over lines with a trailing comma comes back
on one line; review the diff for that.

**Rewrite the smallest node that changes.** A rewrite replaces the whole
matched node with the template, and a template with `$$$ARGS` joins the
captured arguments back together on one line:

```bash
ast-grep run --lang python -p 'load($$$A)' -r 'fetch($$$A)' .
```

turns a multi-line `load(\n    "c",\n    verbose=True,\n)` into
`fetch("c",\nverbose=True,)`. The formatter repairs it, but for a rename the
identifier-only rule above leaves the arguments untouched.

Restructuring a statement is fine, because the whole statement is meant to
change:

```bash
ast-grep run --lang python -p 'self.assertEqual($A, $B)' -r 'assert $A == $B' -U .
```

## YAML rules

A rule file runs with `ast-grep scan -r rule.yml -U <paths>`. Rules can be
narrowed with `kind`, `regex`, `inside`, `has` and `precedes`, which a bare
pattern can't express. Several rules can share one file, separated by `---`.
For a one-off, write the rule to a temp file, or pass the YAML text with
`--inline-rules`.

### Remove every use of a keyword argument

Deleting an argument also has to delete one comma. `fix.expandEnd` and
`fix.expandStart` widen the replaced range to a neighbouring comma, and two
rules pick the right side:

```yaml
id: drop-verbose-before-comma
language: python
rule:
  kind: keyword_argument
  has: { field: name, regex: ^verbose$ }
  precedes: { regex: '^,$' }
fix:
  template: ''
  expandEnd: { regex: '^,$' }
---
id: drop-verbose-last
language: python
rule:
  kind: keyword_argument
  has: { field: name, regex: ^verbose$ }
  not: { precedes: { regex: '^,$' } }
fix:
  template: ''
  expandStart: { regex: '^,$' }
```

After `ruff format`, `load("a", verbose=True)` becomes `load("a")`,
`load(verbose=True, retries=3)` becomes `load(retries=3)`, and a multi-line
call with a trailing comma stays multi-line. The `def`'s `verbose=False`
parameter is a different node kind and is not touched. A pattern such as
`$F($$$PRE, verbose=$V, $$$POST)` is not a substitute: it misses the calls
where `verbose` comes first or last.

### Compute the replacement with `transform`

`transform` derives new variables from captured ones, with `replace` (regex,
with named capture groups usable in `by`), `substring`, `convert` (case) and
`rewrite`. This renames every called `get_*` function to `fetch_*`:

```yaml
id: get-to-fetch
language: python
rule:
  pattern: $NAME
  kind: identifier
  regex: ^get_
  inside: { kind: call, field: function }
transform:
  NEW_NAME: replace($NAME, replace='^get_', by='fetch_')
fix: $NEW_NAME
```

Transform variable names have no `$` where they are defined and take one where
they are used. A fix string can't append uppercase text to a metavariable
(`$NAMESuffix` reads as one variable); build the name in a transform instead.
Docs: <https://ast-grep.github.io/guide/rewrite-code.html> and
<https://ast-grep.github.io/guide/rewrite/transform.html>.

## Where it doesn't fit

- **Finding importers of a deleted module.** The type checker over the whole
  repo lists every unresolved import in under a second, with no rule to write.
- **Prose, config and string values** (an app name in strings, TOML, YAML, docs).
  An AST adds nothing there: `rg -l` and `sed`, then run the tests that pin
  those values.
- **Jinja templates.** The HTML parser matches plain markup, but `{% %}` and
  `{{ }}` are opaque text, so there are no structural edits to template logic.
  Use `rg` and `sed`, and render the templates through tests: no linter
  notices a deleted `{% include %}` target.
- **Python 3.15 `lazy` imports.** tree-sitter-python doesn't parse PEP 810 yet
  (tree-sitter-python issue #335). Simple patterns still match the
  `from x import y` inside `lazy from x import y`, and a rewrite keeps the
  `lazy` prefix. Rules that depend on the node `kind` around a lazy import may
  misbehave; preview them.
