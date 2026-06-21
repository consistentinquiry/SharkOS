-- Editor UI: statusline, indent guides, and the animated indent-scope line.
return {
  -- Statusline. theme = "auto" derives its colours from the active colourscheme,
  -- so it tracks the sharkOS theme too.
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        section_separators = "",
        component_separators = "",
      },
    },
  },

  -- Static indent guides for every level.
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      -- The active scope is drawn (and animated) by mini.indentscope instead.
      scope = { enabled = false },
    },
  },

  -- The animated indent-scope line: when the cursor enters a code block, the
  -- vertical line for that scope is drawn with a growing animation.
  {
    "echasnovski/mini.indentscope",
    version = false,
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
      local indentscope = require("mini.indentscope")
      return {
        symbol = "│",
        options = { try_as_border = true },
        draw = {
          delay = 50,
          -- Quadratic ease-out: a quick, smooth grow as you enter the block.
          animation = indentscope.gen_animation.quadratic({
            easing = "out",
            duration = 20,
            unit = "step",
          }),
        },
      }
    end,
    init = function()
      -- No scope line in these buffers (it's noise there).
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "help", "neo-tree", "lazy", "mason", "Telescope", "txt" },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  -- Keymap discovery popup.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
