-- Formatting via conform.nvim. Shell scripts are formatted with shfmt; any
-- filetype without a configured formatter falls back to the LSP formatter.
-- <leader>cf formats the buffer (normal + visual range).
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format buffer/selection",
    },
  },
  opts = {
    formatters_by_ft = {
      sh = { "shfmt" },
      bash = { "shfmt" },
    },
    -- Everything else: defer to the attached language server.
    default_format_opts = { lsp_format = "fallback" },
    formatters = {
      -- 2-space indent + indented switch-case branches, matching the existing
      -- sharkOS shell scripts.
      shfmt = { prepend_args = { "-i", "2", "-ci" } },
    },
  },
}
