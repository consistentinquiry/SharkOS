-- Theme integration with the sharkOS theme engine.
--
-- apply-theme.sh renders config/themes/templates/nvim-colors.lua.tpl into
-- lua/sharkos_palette.lua (a base16 palette built from the active theme's
-- terminal colours). base16-nvim turns that 16-colour palette into a complete,
-- treesitter- and LSP-aware colourscheme — so Neovim tracks whatever sharkOS
-- theme is selected, exactly like waybar/ghostty/btop.
--
-- Live switching: apply-theme.sh broadcasts :SharkReloadTheme to running nvim
-- instances, which re-reads the palette without a restart.

-- Fallback palette (used only before the first theme has been applied, so a
-- fresh nvim still renders sensibly). Mirrors the "noir" terminal palette.
local FALLBACK = {
  base00 = "#000000", base01 = "#0a0a0a", base02 = "#404040", base03 = "#404040",
  base04 = "#c0c0c0", base05 = "#ffffff", base06 = "#c0c0c0", base07 = "#e8e8e8",
  base08 = "#c4676c", base09 = "#e07a7f", base0A = "#d4a76a", base0B = "#7db88f",
  base0C = "#7bb8c4", base0D = "#6e95bd", base0E = "#b07eb5", base0F = "#c4676c",
}

-- Groups forced transparent so ghostty's frosted-glass background shows through
-- the editor area, matching the rest of the desktop. Popups/floats keep their
-- solid base16 backgrounds for readability.
local TRANSPARENT = {
  "Normal", "NormalNC", "SignColumn", "EndOfBuffer",
  "LineNr", "CursorLineNr", "FoldColumn",
}

local function apply()
  package.loaded.sharkos_palette = nil
  local ok, palette = pcall(require, "sharkos_palette")
  if not ok or type(palette) ~= "table" then
    palette = FALLBACK
  end
  require("base16-colorscheme").setup(palette)
  for _, group in ipairs(TRANSPARENT) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

return {
  "RRethy/base16-nvim",
  lazy = false,
  priority = 1000, -- load before everything else so highlights are set early
  config = function()
    apply()
    -- Re-apply transparency whenever any colourscheme reloads.
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        for _, group in ipairs(TRANSPARENT) do
          vim.api.nvim_set_hl(0, group, { bg = "none" })
        end
      end,
    })
    -- Hook used by apply-theme.sh to live-reload the palette on theme switch.
    vim.api.nvim_create_user_command("SharkReloadTheme", apply, {
      desc = "Reload the sharkOS theme palette",
    })
  end,
}
