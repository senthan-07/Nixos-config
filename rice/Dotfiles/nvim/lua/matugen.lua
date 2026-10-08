 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#13121c',
    base01 = '#201e29',
    base02 = '#2a2933',
    base03 = '#928ea5',
    base04 = '#c8c3dc',
    base05 = '#e5e0ef',
    base06 = '#e5e0ef',
    base07 = '#e5e0ef',
    base08 = '#ffb4ab',
    base09 = '#c6bfff',
    base0A = '#94cdf7',
    base0B = '#89ceff',
    base0C = '#c6bfff',
    base0D = '#89ceff',
    base0E = '#94cdf7',
    base0F = '#c9e6ff',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#e5e0ef',          bg = '#13121c' })
  hi('TelescopeBorder',         { fg = '#928ea5',             bg = '#13121c' })
  hi('TelescopePromptNormal',   { fg = '#e5e0ef',          bg = '#13121c' })
  hi('TelescopePromptBorder',   { fg = '#928ea5',             bg = '#13121c' })
  hi('TelescopePromptPrefix',   { fg = '#89ceff',             bg = '#13121c' })
  hi('TelescopePromptCounter',  { fg = '#c8c3dc',  bg = '#13121c' })
  hi('TelescopePromptTitle',    { fg = '#13121c',             bg = '#89ceff' })
  hi('TelescopePreviewTitle',   { fg = '#13121c',             bg = '#94cdf7' })
  hi('TelescopeResultsTitle',   { fg = '#13121c',             bg = '#c6bfff' })
  hi('TelescopeSelection',      { fg = '#e5e0ef',          bg = '#2a2933' })
  hi('TelescopeSelectionCaret', { fg = '#89ceff',             bg = '#2a2933' })
  hi('TelescopeMatching',       { fg = '#89ceff',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#e5e0ef',          bg = '#13121c' })
  hi('MiniPickBorder',         { fg = '#928ea5',             bg = '#13121c' })
  hi('MiniPickPrompt',   { fg = '#e5e0ef',          bg = '#13121c' })
  hi('MiniPickPromptPrefix',   { fg = '#89ceff',             bg = '#13121c' })
  hi('MiniPickBorderText',    { fg = '#13121c',             bg = '#89ceff' })
  hi('MiniPickMatchCurrent',      { fg = '#e5e0ef',          bg = '#2a2933' })
  hi('MiniPickPromptCaret', { fg = '#89ceff',             bg = '#2a2933' })
  hi('MiniPickMatchRanges',       { fg = '#89ceff',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
