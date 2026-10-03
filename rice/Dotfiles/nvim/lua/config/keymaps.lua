-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- Every LazyVim default is untouched: <leader> stays Space and nothing below
-- overrides a built-in binding.

-- <leader>R : re-apply the wallpaper palette after matugen re-renders it.
-- Uppercase leader so it cannot clash with LazyVim's lowercase <leader>r*.
vim.keymap.set("n", "<leader>R", "<cmd>RiceColors<cr>", { desc = "Rice: Re-apply Wallpaper Colors" })
vim.keymap.set("n", "<leader>Rh", function()
  vim.cmd.RiceColors()
  vim.cmd("highlight")
end, { desc = "Rice: Re-apply Colors + Redraw" })