-- ~/.config/nvim/lua/config/blink.lua

return {
  {
    "blink.cmp",
    opts = {
      completion = {
        ghost_text = {
          enabled = false, -- Disable ghost text
        },
      },
    },
  },
}
