-- Completion. blink.cmp ships a prebuilt binary (version = "*"), so there's no
-- Rust build step on install — no heavy compile, no OOM risk.
return {
  "saghen/blink.cmp",
  version = "*",
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    keymap = { preset = "default" }, -- <C-space> open, <C-y> accept, <C-n>/<C-p> nav
    appearance = { nerd_font_variant = "mono" },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      menu = { border = "rounded" },
    },
    signature = { enabled = true, window = { border = "rounded" } },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
  },
}
