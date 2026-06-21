-- Java IDE support via nvim-jdtls (Eclipse JDT language server). jdtls is a
-- stateful, per-project server, so it's started per buffer rather than through
-- lspconfig. Mason installs the `jdtls` package (see lsp.lua ensure_installed)
-- and puts a `jdtls` launcher on Neovim's PATH.
return {
  "mfussenegger/nvim-jdtls",
  ft = "java",
  config = function()
    local function start_jdtls()
      local root = vim.fs.root(0, {
        ".git", "mvnw", "gradlew", "pom.xml", "build.gradle", "settings.gradle",
      }) or vim.fn.getcwd()

      -- Per-project workspace, keyed by the project directory name.
      local workspace = vim.fn.stdpath("cache")
        .. "/jdtls/" .. vim.fn.fnamemodify(root, ":p:h:t")

      require("jdtls").start_or_attach({
        cmd = { "jdtls", "-data", workspace },
        root_dir = root,
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })
    end

    -- Lazy-loading on ft=java means the FileType event for the first Java buffer
    -- has already fired by the time this config runs — start it directly — and
    -- register an autocmd for any subsequently opened Java buffers.
    start_jdtls()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = start_jdtls,
    })
  end,
}
