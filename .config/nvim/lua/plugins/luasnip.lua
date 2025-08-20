return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",                    -- Follow the latest release.
    build = "make install_jsregexp",     -- Install jsregexp for LuaSnip.
    config = function()
      require("luasnip").config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI",
      })
      require("luasnip.loaders.from_vscode").lazy_load()                                           -- Load VS Code-style snippets lazily.
      require("luasnip.loaders.from_lua").load({ paths = { "~/.config/nvim/lua/snippets/" } })     -- Load Lua snippets.
    end,
  },
}
