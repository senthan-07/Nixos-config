-- rice-matugen: LazyVim highlight overrides from the wallpaper.
--
-- rice/matugen/templates/nvim-colors.lua renders
-- lua/config/rice-colors-generated.lua next to this file. This module reads it
-- and overrides the highlight groups that LazyVim's own colourscheme set, so
-- LSP, Treesitter, Telescope, gitsigns, which-key, lualine and the rest keep
-- working exactly as LazyVim configures them — only the colours change.
--
-- If the generated file is absent (matugen has not run yet, or the "nvim"
-- target is off in the rice settings), nothing is overridden and LazyVim's
-- default colourscheme is used.
--
-- New Neovim instances pick up a new palette automatically. To re-apply in a
-- running session: :RiceColors

local M = {}

local generated = "config.rice-colors-generated"

---Highlight groups that take their colours from the Material You palette.
---Kept deliberately small: anything LazyVim links to another group (so it
---follows along) is left alone.
local function palette(c)
  return {
    -- core UI --------------------------------------------------------
    Normal = { fg = c.on_surface, bg = c.surface },
    NormalNC = { fg = c.on_surface, bg = c.surface },
    NormalFloat = { fg = c.on_surface, bg = c.surface_container_high },
    FloatBorder = { fg = c.outline_variant, bg = c.surface_container_high },
    FloatTitle = { fg = c.tertiary, bg = c.surface_container_high, bold = true },

    CursorLine = { bg = c.surface_container },
    CursorLineNr = { fg = c.primary, bold = true },
    CursorLineSign = { bg = c.surface_container },
    CursorLineFold = { bg = c.surface_container },

    Visual = { bg = c.primary_container },
    VisualNOS = { bg = c.primary_container },

    Search = { bg = c.tertiary_container },
    IncSearch = { bg = c.primary_container, bold = true },
    CurSearch = { bg = c.primary_container, bold = true },
    Substitute = { bg = c.error_container },

    LineNr = { fg = c.outline_variant },
    LineNrAbove = { fg = c.on_surface_variant },
    LineNrBelow = { fg = c.outline_variant },
    SignColumn = { fg = c.on_surface_variant, bg = c.surface },
    Folded = { fg = c.on_surface_variant, bg = c.surface_container },
    FoldColumn = { fg = c.outline_variant, bg = c.surface },

    StatusLine = { fg = c.on_surface, bg = c.surface_container },
    StatusLineNC = { fg = c.on_surface_variant, bg = c.surface_container },
    WinBar = { fg = c.on_surface, bg = c.surface_container },
    WinBarNC = { fg = c.on_surface_variant, bg = c.surface_container },

    Pmenu = { bg = c.surface_container_high },
    PmenuSel = { fg = c.on_primary_container, bg = c.primary_container, bold = true },
    PmenuSbar = { bg = c.surface_container_highest },
    PmenuThumb = { bg = c.outline_variant },
    PmenuKind = { fg = c.tertiary, bg = c.surface_container_high },
    PmenuExtra = { fg = c.on_surface_variant, bg = c.surface_container_high },
    PmenuMatch = { fg = c.primary, bg = c.surface_container_high, bold = true },
    PmenuMatchSel = { fg = c.primary, bg = c.primary_container, bold = true },

    QuickFixLine = { bg = c.surface_container_high, bold = true },
    MsgArea = { fg = c.on_surface_variant },
    MsgSeparator = { fg = c.outline_variant },
    ComplMatchIns = { fg = c.tertiary, bg = c.surface_container_highest },
    SpellBad = { sp = c.error, undercurl = true },
    SpellCap = { sp = c.tertiary, undercurl = true },
    SpellLocal = { sp = c.primary, undercurl = true },
    ColorColumn = { bg = c.surface_container_low },

    -- diffs ----------------------------------------------------------
    DiffAdd = { bg = c.primary_container },
    DiffChange = { bg = c.secondary_container },
    DiffDelete = { bg = c.error_container },
    DiffText = { bg = c.tertiary_container },

    -- diagnostics ----------------------------------------------------
    DiagnosticError = { fg = c.error },
    DiagnosticWarn = { fg = c.tertiary },
    DiagnosticInfo = { fg = c.primary },
    DiagnosticHint = { fg = c.secondary },
    DiagnosticOk = { fg = c.primary },
    DiagnosticSignError = { fg = c.error },
    DiagnosticSignWarn = { fg = c.tertiary },
    DiagnosticSignInfo = { fg = c.primary },
    DiagnosticSignHint = { fg = c.secondary },
    DiagnosticSignOk = { fg = c.primary },
    DiagnosticVirtualTextError = { fg = c.on_error_container, bg = c.error_container },
    DiagnosticVirtualTextWarn = { fg = c.on_tertiary_container, bg = c.tertiary_container },
    DiagnosticVirtualTextInfo = { fg = c.on_primary_container, bg = c.primary_container },
    DiagnosticVirtualTextHint = { fg = c.on_secondary_container, bg = c.secondary_container },
    DiagnosticUnderlineError = { sp = c.error, undercurl = true },
    DiagnosticUnderlineWarn = { sp = c.tertiary, undercurl = true },
    DiagnosticUnderlineInfo = { sp = c.primary, undercurl = true },
    DiagnosticUnderlineHint = { sp = c.secondary, undercurl = true },
    DiagnosticFloatingError = { fg = c.error },
    DiagnosticFloatingWarn = { fg = c.tertiary },
    DiagnosticFloatingInfo = { fg = c.primary },
    DiagnosticFloatingHint = { fg = c.secondary },

    -- treesitter -----------------------------------------------------
    ["@comment"] = { fg = c.on_surface_variant, italic = true },
    ["@comment.error"] = { fg = c.error, italic = true },
    ["@comment.warning"] = { fg = c.tertiary, italic = true },
    ["@comment.note"] = { fg = c.primary, italic = true },
    ["@comment.todo"] = { fg = c.primary, italic = true, bold = true },
    ["@variable"] = { fg = c.on_surface },
    ["@variable.builtin"] = { fg = c.tertiary, italic = true },
    ["@variable.parameter"] = { fg = c.on_surface_variant },
    ["@variable.member"] = { fg = c.on_surface },
    ["@constant"] = { fg = c.tertiary },
    ["@constant.builtin"] = { fg = c.tertiary, italic = true },
    ["@constant.macro"] = { fg = c.secondary, italic = true },
    ["@module"] = { fg = c.on_surface_variant },
    ["@label"] = { fg = c.secondary },
    ["@string"] = { fg = c.tertiary },
    ["@string.documentation"] = { fg = c.on_surface_variant, italic = true },
    ["@string.regexp"] = { fg = c.secondary },
    ["@string.escape"] = { fg = c.tertiary, bold = true },
    ["@string.special.symbol"] = { fg = c.secondary },
    ["@character"] = { fg = c.tertiary },
    ["@boolean"] = { fg = c.tertiary },
    ["@number"] = { fg = c.tertiary },
    ["@number.float"] = { fg = c.tertiary },
    ["@type"] = { fg = c.secondary },
    ["@type.builtin"] = { fg = c.secondary, italic = true },
    ["@type.definition"] = { fg = c.on_surface_variant },
    ["@attribute"] = { fg = c.secondary },
    ["@property"] = { fg = c.tertiary },
    ["@function"] = { fg = c.primary },
    ["@function.builtin"] = { fg = c.primary, italic = true },
    ["@function.call"] = { fg = c.primary },
    ["@function.macro"] = { fg = c.secondary },
    ["@function.method"] = { fg = c.primary },
    ["@constructor"] = { fg = c.secondary },
    ["@operator"] = { fg = c.on_surface_variant },
    ["@keyword"] = { fg = c.primary },
    ["@keyword.conditional"] = { fg = c.primary },
    ["@keyword.repeat"] = { fg = c.primary },
    ["@keyword.return"] = { fg = c.primary },
    ["@keyword.exception"] = { fg = c.primary },
    ["@keyword.function"] = { fg = c.primary },
    ["@keyword.operator"] = { fg = c.primary },
    ["@keyword.import"] = { fg = c.primary },
    ["@keyword.directive"] = { fg = c.primary },
    ["@keyword.repeat.underline"] = { underline = true },
    ["@punctuation.delimiter"] = { fg = c.on_surface_variant },
    ["@punctuation.bracket"] = { fg = c.on_surface_variant },
    ["@punctuation.special"] = { fg = c.on_surface_variant },
    ["@markup.heading"] = { fg = c.primary, bold = true },
    ["@markup.strong"] = { bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.underline"] = { underline = true },
    ["@markup.heading.1"] = { fg = c.primary, bold = true },
    ["@markup.heading.2"] = { fg = c.secondary, bold = true },
    ["@markup.heading.3"] = { fg = c.tertiary, bold = true },
    ["@markup.heading.4"] = { fg = c.on_surface, bold = true },
    ["@markup.heading.5"] = { fg = c.on_surface_variant, bold = true },
    ["@markup.heading.6"] = { fg = c.on_surface_variant, bold = true },
    ["@markup.quote"] = { fg = c.on_surface_variant, italic = true },
    ["@markup.math"] = { fg = c.tertiary },
    ["@markup.link"] = { fg = c.primary, underline = true },
    ["@markup.link.label"] = { fg = c.secondary },
    ["@markup.link.url"] = { fg = c.tertiary, underline = true },
    ["@markup.raw"] = { fg = c.tertiary },
    ["@markup.list"] = { fg = c.primary },
    ["@markup.list.checked"] = { fg = c.primary },
    ["@markup.list.unchecked"] = { fg = c.on_surface_variant },
    ["@diff.plus"] = { fg = c.primary },
    ["@diff.minus"] = { fg = c.error },
    ["@diff.delta"] = { fg = c.tertiary },
    ["@tag"] = { fg = c.secondary },
    ["@tag.builtin"] = { fg = c.tertiary },
    ["@tag.attribute"] = { fg = c.on_surface_variant },
    ["@tag.delimiter"] = { fg = c.on_surface_variant },

    -- LSP semantic tokens --------------------------------------------
    ["@lsp.type.boolean"] = { fg = c.tertiary },
    ["@lsp.type.builtinType"] = { fg = c.secondary, italic = true },
    ["@lsp.type.comment"] = {},
    ["@lsp.type.construct"] = { fg = c.tertiary },
    ["@lsp.type.enum"] = { fg = c.secondary },
    ["@lsp.type.enumMember"] = { fg = c.tertiary },
    ["@lsp.type.escapeSequence"] = { fg = c.tertiary, bold = true },
    ["@lsp.type.formatSpecifier"] = { fg = c.tertiary },
    ["@lsp.type.interface"] = { fg = c.secondary },
    ["@lsp.type.keyword"] = { fg = c.primary },
    ["@lsp.type.namespace"] = { fg = c.on_surface_variant },
    ["@lsp.type.number"] = { fg = c.tertiary },
    ["@lsp.type.operator"] = { fg = c.on_surface_variant },
    ["@lsp.type.parameter"] = { fg = c.on_surface_variant },
    ["@lsp.type.property"] = { fg = c.tertiary },
    ["@lsp.type.selfKeyword"] = { fg = c.primary },
    ["@lsp.type.typeAlias"] = { fg = c.secondary },
    ["@lsp.type.unresolvedReference"] = { fg = c.error },
    ["@lsp.type.variable"] = {},
    ["@lsp.type.variable.builtin"] = { fg = c.tertiary, italic = true },
    ["@lsp.typemod.function.defaultLibrary"] = { fg = c.primary, italic = true },
    ["@lsp.typemod.variable.defaultLibrary"] = { fg = c.on_surface, italic = true },
    ["@lsp.typemod.variable.readonly"] = { fg = c.on_surface },
    ["@lsp.mod.deprecated"] = { strikethrough = true },
    ["@lsp.mod.readonly"] = { fg = c.on_surface },

    -- health ---------------------------------------------------------
    healthError = { fg = c.error },
    healthWarning = { fg = c.tertiary },
    healthSuccess = { fg = c.primary },
    healthHelp = { fg = c.secondary },

    -- lazy.nvim ------------------------------------------------------
    LazyNormal = { fg = c.on_surface, bg = c.surface_container_high },
    LazyButton = { fg = c.primary, bg = c.surface_container_high },
    LazyButtonActive = { fg = c.on_primary_container, bg = c.primary_container },
    LazyH1 = { fg = c.primary, bold = true },
    LazyH2 = { fg = c.secondary, bold = true },
    LazyComment = { fg = c.on_surface_variant },
    LazyCommit = { fg = c.on_surface },
    LazyCommitIssue = { fg = c.error },
    LazyCommitScope = { fg = c.secondary, italic = true },
    LazyCommitType = { fg = c.tertiary, bold = true },
    LazyDimmed = { fg = c.on_surface_variant },
    LazyDir = { fg = c.primary },
    LazyUrl = { fg = c.tertiary, underline = true },
    LazyNoCond = { fg = c.tertiary },
    LazyProgressDone = { fg = c.primary, bold = true },
    LazyProgressTodo = { fg = c.surface_container_highest, bold = true },
    LazyProp = { fg = c.on_surface },
    LazyReasonCmd = { fg = c.on_surface_variant },
    LazyReasonEvent = { fg = c.secondary },
    LazyReasonFt = { fg = c.tertiary },
    LazyReasonImport = { fg = c.tertiary },
    LazyReasonKeys = { fg = c.on_surface_variant },
    LazyReasonPlugin = { fg = c.primary },
    LazyReasonRuntime = { fg = c.error },
    LazyReasonSource = { fg = c.on_surface_variant },
    LazyReasonStart = { fg = c.tertiary },
    LazySpecial = { fg = c.primary },
    LazyTaskError = { fg = c.error },
    LazyTaskOutput = { fg = c.on_surface },
    LazyValue = { fg = c.tertiary },
  }
end

---Colour the built-in :terminal with the same palette.
local function terminal(c)
  local t = {
    [0] = c.surface,
    [1] = c.error,
    [2] = c.tertiary,
    [3] = c.secondary,
    [4] = c.primary,
    [5] = c.tertiary_container,
    [6] = c.secondary_container,
    [7] = c.on_surface,
    [8] = c.outline_variant,
    [9] = c.on_error_container,
    [10] = c.on_tertiary_container,
    [11] = c.on_secondary_container,
    [12] = c.on_primary_container,
    [13] = c.tertiary_fixed,
    [14] = c.secondary_fixed,
    [15] = c.on_surface,
  }
  for i, colour in pairs(t) do
    vim.g["terminal_color_" .. i] = colour
  end
end

---Apply the generated palette on top of whatever colourscheme is active.
---@return boolean applied
function M.apply()
  local ok, c = pcall(require, generated)
  if not ok or type(c) ~= "table" or not c.primary or not c.surface then return false end

  -- Match a light wallpaper the same way LazyVim's colourscheme would. Set
  -- before the highlights so it cannot clear them again.
  vim.o.background = c.mode == "light" and "light" or "dark"

  for group, opts in pairs(palette(c)) do
    pcall(vim.api.nvim_set_hl, 0, group, opts)
  end

  vim.g.terminal_color_background = c.surface
  terminal(c)

  return true
end

function M.setup()
  -- Re-apply whenever a colourscheme is (re)loaded, so `:colorscheme`, `:Lazygit`
  -- style reloads and LazyVim's own late colourscheme setup keep the palette.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("rice_colors", { clear = true }),
    callback = function()
      M.apply()
    end,
  })

  local function notify(msg, level)
    vim.notify(msg, level, { title = "rice colors" })
  end

  vim.api.nvim_create_user_command("RiceColors", function()
    -- Drop the cached module so a re-render is picked up without restarting.
    package.loaded[generated] = nil
    if M.apply() then
      notify("Applied the rice palette.")
    else
      notify("No rice palette yet (matugen has not rendered rice-colors-generated.lua).", vim.log.levels.WARN)
    end
  end, { desc = "Re-apply the wallpaper palette (matugen)" })

  if M.apply() then
    vim.g.rice_colors = true
  end
end

return M