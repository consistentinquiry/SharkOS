-- Leader must be set before lazy.nvim loads so plugin <leader> keymaps register.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.showmode = false           -- the statusline shows the mode
opt.clipboard = "unnamedplus"  -- share the system clipboard (wl-clipboard)
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 400
opt.splitright = true
opt.splitbelow = true
opt.inccommand = "split"
opt.cursorline = true
opt.scrolloff = 8
opt.termguicolors = true       -- 24-bit colour (matches the themed palette)
opt.signcolumn = "yes"

-- Indentation: 2 spaces by default; ftplugins/treesitter refine per language.
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Python and Java conventionally use 4 spaces.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "java" },
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})
