return {

  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      strategies = {
        chat = {
          adapter = "deepseek",
          inline = "deepseek",
        },
      },
      adapters = {
        deepseek = function()
          return require("codecompanion.adapters").extend("ollama", {
            name = "deepseek", -- Custom adapter name
            schema = {
              model = {
                default = "deepseek-r1:8b",
              },
            },
          })
        end,
      },
      opts = {
        log_level = "DEBUG",
      },
      display = {
        diff = {
          enabled = true,
          close_chat_at = 240,
          layout = "vertical",
          opts = { "internal", "filler", "closeoff", "algorithm:patience", "followwrap", "linematch:120" },
          provider = "default",
        },
      },
    },
  },
}
