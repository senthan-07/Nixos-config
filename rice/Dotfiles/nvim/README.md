# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

## Upstream

Cloned from <https://github.com/LazyVim/starter.git> (branch `main`, at
`803bc18`) and then vendored into this repo, so the config is tracked as normal
files here like the rest of the rice. To re-sync with upstream:

```sh
git remote add starter https://github.com/LazyVim/starter.git
git fetch starter
git diff starter/main -- lua/config/lazy.lua lua/config/options.lua
```

## Local changes on top of the starter

| File | Purpose |
| --- | --- |
| `lua/plugins/colors.lua` | Sets Catppuccin as the fallback colourscheme. |
| `lua/config/rice-colors.lua` | Layers the matugen/wallpaper palette on top of the active colourscheme. Adds `:RiceColors`. |
| `lua/config/autocmds.lua` | Calls `config.rice-colors.setup()` on VeryLazy. |
| `lua/config/keymaps.lua` | Adds only `<leader>R` / `<leader>Rh`; no LazyVim default is overridden. |
| `lua/config/rice-colors-generated.lua` | **Generated** by rice/matugen. Ignored by git, never edit. |

The palette file is rendered from
`rice/matugen/templates/nvim-colors.lua` by `rice/matugen/apply.sh` whenever the
wallpaper changes and the `nvim` target is enabled. If it is missing, LazyVim
just uses Catppuccin as normal.