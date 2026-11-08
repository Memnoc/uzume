# Restore native inline diagnostic display

Date: 2026-11-08. Status: fixed in the editor preview on `spike/editor-baseline`.

## Report and reproduction

Memnoc reported that the Rust LSP did not seem to behave like LazyVim and supplied
screenshots. The accessible editor screenshot showed a missing semicolon after
`args.next()`, inline rust-analyzer/rustc messages, underlines and severity icons.
The other accessible replacement image was unrelated and excluded. The original
ai-nvim screenshot remained inaccessible in macOS's capture directory, so this
investigation establishes the reproduced display gap, not every possible
project-specific difference.

A disposable Rust Cargo project reduced the screenshot example to seven lines.
The real installed rust-analyzer attached and emitted
`Syntax Error: expected SEMICOLON`. The feedback loop captured both diagnostics
and the buffer's actual virtual-text extmarks in one RPC snapshot. It failed:
there was a diagnostic but no rendered inline message. An earlier two-step probe
hit a diagnostic-refresh race; atomic capture removed that ambiguity.

Command used: `python3 /tmp/ainvim-rust-display-probe.py`.
Before the fix: `FAIL: rust-analyzer reports the error but no inline diagnostic
message is rendered`.

## Hypotheses and finding

Ranked hypotheses were a global display setting suppressing inline text, a
per-server override suppressing it, or different server settings affecting the
reported diagnostic set. Changing only native `virtual_text` in the disposable
session rendered the existing error, confirming the first explanation.

Our baseline retained `virtual_text = false` from My-LazyVim's early options.
LazyVim's LSP plugin subsequently configures a virtual-text table, overriding
that early value. We copied an intermediate setting rather than the effective
runtime behavior. rust-analyzer itself was already producing the diagnostic.

## Fix and controls

`editor/lua/ainvim/options.lua` now explicitly configures native inline messages,
underlines, four-space spacing, dot prefixes, conditional source labels, severity
sorting and familiar error/warning/hint/info gutter icons. Diagnostics do not
update during Insert mode. Rounded diagnostic floats remain available.

Existing controls remain: Space cd for full line diagnostics, ]d/[d to navigate,
Space sD for the buffer picker, and Space ud to toggle diagnostics. No new plugin,
server version, package installation or Rust-specific override was introduced.
Inlay hints are a separate feature and are not enabled by this change.

## Verification and prevention

The same real-server probe passed using the fixed startup configuration, without
a runtime override. It also inserted the missing semicolon into the disposable
file, saved it and verified that the errors and their stale inline text cleared.
The probe exercises rendered text rather than merely asserting configuration
values. It remains a disposable debug probe under `.probe/debug/` on the editor
worktree, consistent with the ongoing spike; no permanent test suite was added.
Lua formatting and whitespace checks passed.

Prevent recurrence by comparing the effective runtime settings of the reference
editor and asserting visible diagnostic output. Successful server attachment
and diagnostic publication alone do not establish a usable diagnostic display.
No architecture change is needed for this fix. Main retains the finding; runtime
code remains on the editor spike branch.
