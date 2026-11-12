# Uzume colorscheme

**Uzume** is the distribution's default dark colorscheme. Mauve gives structure to
the interface and code; warm orange draws attention to calls and Markdown context.
Gold, sage and rose keep strings, types and values distinguishable.

## Controls and preferences

- **Space uC**: preview and select an installed colorscheme.
- `:colorscheme uzume`: return to Uzume.
- `:colorscheme rose-pine` or `:colorscheme rose-pine-main`: original Rose Pine.
- `:colorscheme rose-pine-moon` / `:colorscheme rose-pine-dawn`: its dark/light variants.
- Other installed themes, including Neovim's built-in themes, use the same picker.

Selecting a theme does not write a persistent preference. Uzume starts with its
own theme by default. To choose another default without changing distribution files:

```sh
uzume --cmd 'let g:uzume_colorscheme = "rose-pine"'
```

A separate zsh function can make that choice convenient:

```sh
uzume-rose() { uzume --cmd 'let g:uzume_colorscheme = "rose-pine"' "$@"; }
```

This requires the selected colorscheme to be installed. The distribution bundles
Rose Pine and Neovim's built-in themes; it does not install a new theme merely by
naming it. Normal `nvim` and its configuration are unaffected.

## Palette and intent

| Role | Color | Purpose |
| --- | --- | --- |
| Base / surface / overlay | `#191724` / `#1f1d2e` / `#26233a` | Quiet dark backgrounds |
| Ordinary text | `#e0d4eb` | Pale mauve neutral |
| Comments / secondary text / inlay hints | `#a99ab8` | Readable supporting detail |
| Muted decoration | `#8b7c98` | Low-priority borders and gutters |
| UI accent / keywords / Markdown headings and list markers | `#c4a7e7` | Mauve structure |
| Functions / methods / string escapes / Markdown links and inline code | `#f6ad75` | Warm orange emphasis |
| Strings / characters | `#e7c58a` | Soft gold literal text |
| Types / constructors / tags | `#b8cda4` | Sage type information |
| Numbers / constants / booleans | `#ebbcba` | Rose values |
| Parameters / members / operators | `#d1bedb` | Pale lavender detail |

Existing bold, italic and underline styling is retained. Ordinary variables remain
neutral. File icons keep their recognizable colors. Shared HTML/Vimwiki/Neorg
heading/link aliases retain their original document colors rather than inheriting
Markdown-specific overrides.

Errors remain Rose Pine love (`#eb6f92`), warnings gold (`#f6c177`), information foam
(`#9ccfd8`) and hints iris (`#c4a7e7`). Git diff backgrounds, signs and diagnostic
severity colors retain their original meanings. The missing-newline Git preview
label explicitly keeps its original gold even though constants are now rose.
Terminal ANSI colors retain the underlying Rose Pine roles; truecolor applications
such as Codex and Claude may draw their own colors.

## Implementation and dependency boundary

- [colors/uzume.lua](../../editor/colors/uzume.lua) is the standard Neovim entry point.
- [ui/theme.lua](../../editor/lua/uzume/ui/theme.lua) owns the palette and role mappings.
- [editor/ui.lua](../../editor/lua/uzume/editor/ui.lua) selects the startup theme.

The implementation uses the existing, exactly pinned [Rose Pine Neovim theme](https://github.com/rose-pine/neovim)
as its renderer and plugin highlight foundation. Uzume is a named derivative, not
a standalone replacement or an upstream Rose Pine release. No new dependency is
added and the installed plugin is not patched.

Rendering temporarily applies Uzume's configuration to Rose Pine, clears its palette
cache for that render, then restores the prior options and palette cache. Restoration
also runs after a render error. The completed theme reports `vim.g.colors_name` as
`uzume`, so native selection, completion, previews and ColorScheme listeners use the
correct identity. No global recoloring hook runs on other colorschemes.

Native syntax, Tree-sitter captures and their linked LSP semantic tokens are covered.
Language-specific parser/server groups may have additional styling. Uzume is dark-only;
choose Rose Pine Dawn or another installed light theme for a light background.
The prototype launcher and `:UzumePalette` comparison command remain on their spike
branch and are not installed as production features.

## Visibility and verification

The accepted warm trial became the named theme on 2026-11-12. The final pass raised
inlay hints from 4.07:1 to 5.99:1 against their tinted background, using the existing
secondary-text color. Other accepted palette roles are unchanged.

Real-editor checks on macOS with Neovim 0.11 and the local development version measured
resolved highlights, including blended backgrounds, rather than palette swatches alone:

| Foreground | Base | Cursor line | Actual visual selection |
| --- | ---: | ---: | ---: |
| Mauve keywords | 8.43:1 | 7.25:1 | 6.30:1 |
| Orange functions | 9.38:1 | 8.06:1 | 7.00:1 |
| Gold strings | 10.72:1 | 9.21:1 | 8.01:1 |
| Sage types | 10.35:1 | 8.89:1 | 7.73:1 |
| Rose values | 10.45:1 | 8.99:1 | 7.81:1 |
| Lavender detail | 10.17:1 | 8.74:1 | 7.60:1 |

Comments measure 6.73:1 on the base. Inlay hints measure 5.99:1. Floating titles and
picker prompts measure 7.88:1; diagnostic virtual text ranges from 5.29:1 to 8.77:1.
The spike's earlier conservative selection estimate used an opaque highlight-medium
background; this pass measures Neovim's actual resolved visual-selection background.

[tests/colorscheme.py](../../tests/colorscheme.py) covers default selection and native
discovery, picker preview/cancel/select, these contrast pairs, diagnostic/diff
consistency, original Rose Pine
colors, switching through Moon/Dawn/Habamax/default and back, and restoration of
custom Rose Pine options. It runs in the consolidated local/Linux CI suite. Dashboard
and floating-command-line regressions also exercise the new default.

Contrast values are calculated sRGB text/background ratios, not a guarantee of color
vision accessibility or comfort. Terminal opacity, fonts, truecolor support and
external application palettes affect the result. Truecolor, opaque backgrounds are
the reference configuration. No claim of exhaustive language or terminal coverage is
made; real-project feedback remains valuable.

## Statusline

Uzume's statusline uses mauve for the mode badge and position indicator in
Normal and Terminal modes, with dark lettering. Project/checkout text is mauve,
and the filename stays pale on a dark surface.
Insert uses sage, Visual orange, Replace rose and Command gold to keep mode
changes visible. Inactive sections use readable secondary text.
`editor/lua/lualine/themes/uzume.lua` is discovered by lualine's existing `auto`
setting; selecting another colorscheme restores that theme's statusline behavior.
