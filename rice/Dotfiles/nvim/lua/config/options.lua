-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Layer the wallpaper palette (rice/matugen) on top of the active colourscheme.
-- This lives here rather than in autocmds.lua on purpose: autocmds.lua is only
-- loaded on VeryLazy, which LazyVim triggers from UIEnter, so it never runs
-- under `nvim --headless` / `nvim -l`. setup() is idempotent, and it re-applies
-- on every ColorScheme event, so it works whichever order that lands in.
require("config.rice-colors").setup()
