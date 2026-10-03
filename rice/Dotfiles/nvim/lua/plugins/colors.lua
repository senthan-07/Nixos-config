-- Fallback colourscheme. The wallpaper palette from rice/matugen is layered on
-- top of this by lua/config/rice-colors.lua, so this is what you see before
-- matugen has rendered lua/config/rice-colors-generated.lua.
-- stylua: ignore
return {
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}