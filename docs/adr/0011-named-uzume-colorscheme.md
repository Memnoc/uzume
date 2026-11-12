# ADR 0011: A named Uzume colorscheme over a pinned renderer

Status: accepted — 2026-11-12

## Context

The user accepted the warm syntax experiment and requested it as Uzume's official
default while retaining original Rose Pine and other themes. Global Rose Pine
configuration would make its name refer to a modified palette and obscure that choice.
Forking its complete plugin highlight implementation would add unnecessary maintenance.

## Decision

Ship a native `colors/uzume.lua` entry point with the accepted palette in
`uzume/ui/theme.lua`. Use the existing pinned Rose Pine implementation as a renderer,
with temporary configuration and palette cache state restored after each render,
including errors. Report the final name as `uzume`; leave theme selection to native
Neovim and the existing picker. Keep the prototype and comparison commands out of main.

The palette uses explicit semantic roles rather than a global cyan-to-orange
replacement. Preserve diagnostic/diff meanings, text styling and shared document
aliases; improve inlay-hint contrast using the existing secondary-text color.

## Consequences

Uzume has a distinct identity and default while `rose-pine` retains its original
colors. There is no extra plugin or installed-plugin mutation. The renderer's option
and palette-cache interfaces are now a small, explicit dependency boundary, protected
by real-editor roundtrip/option-isolation checks and exact dependency pins. Review
that boundary on Rose Pine updates. This is a dark derivative, not a standalone theme
package or a new light variant. See the [feature guide](../features/colorscheme.md).
