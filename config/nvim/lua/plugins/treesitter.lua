-- Syntax-aware highlighting, indentation and text objects. Parsers compile with
-- the system C compiler (gcc, from base-devel).
return {
  "nvim-treesitter/nvim-treesitter",
  -- Pin the classic master branch. The default branch is now the `main`
  -- rewrite, which removes the `nvim-treesitter.configs` setup API this spec
  -- (and most plugins) rely on.
  branch = "master",
  build = ":TSUpdate",
  event = { "BufReadPre", "BufNewFile" },
  main = "nvim-treesitter.configs",
  opts = {
    ensure_installed = {
      "lua", "vim", "vimdoc", "bash", "json", "jsonc", "yaml", "toml",
      "markdown", "markdown_inline", "regex",
      "typescript", "javascript", "tsx",
      "python",
      "java",
      "html", "css",
    },
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true },
  },
}
