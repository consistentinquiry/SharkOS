-- Language servers (hybrid install model):
--   * Runtimes/CLIs (nodejs, python, jdk, ripgrep, fd) come from pacman.txt.
--   * The servers themselves are installed by Mason on first launch and pinned
--     here via ensure_installed.
--
-- jdtls is intentionally NOT auto-enabled here — Java is wired up per-buffer by
-- nvim-jdtls (see java.lua), which Mason still installs via ensure_installed.
return {
  { "mason-org/mason.nvim", opts = {} },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason-lspconfig.nvim",
      "mason-org/mason.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      -- Completion capabilities applied to every server.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Per-server overrides (merged onto lspconfig's shipped defaults).
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "ts_ls", "pyright", "jdtls", "bashls" },
        -- jdtls is started by nvim-jdtls, so keep mason-lspconfig from enabling it.
        automatic_enable = { exclude = { "jdtls" } },
      })

      -- Diagnostics presentation.
      vim.diagnostic.config({
        virtual_text = { spacing = 2, prefix = "●" },
        severity_sort = true,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "",
          },
        },
      })

      -- LSP keymaps, set only on buffers with an attached server.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local map = function(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("gI", vim.lsp.buf.implementation, "Go to implementation")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("K", vim.lsp.buf.hover, "Hover docs")
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          -- Formatting (<leader>cf) is owned by conform.nvim (see formatting.lua),
          -- which routes shell to shfmt and falls back to the LSP otherwise.
          map("[d", function() vim.diagnostic.jump({ count = -1 }) end, "Previous diagnostic")
          map("]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
        end,
      })
    end,
  },
}
