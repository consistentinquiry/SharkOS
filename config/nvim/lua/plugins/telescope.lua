-- Fuzzy finder (files, grep, symbols, diagnostics). Uses ripgrep + fd from
-- pacman.txt for fast searching.
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep (live)" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
    { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
    { "<leader>fr", "<cmd>Telescope lsp_references<cr>", desc = "References" },
    { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document symbols" },
  },
  opts = {
    defaults = {
      prompt_prefix = "  ",
      selection_caret = " ",
      layout_config = { prompt_position = "top" },
      sorting_strategy = "ascending",
    },
  },
}
