return {
    {
        "hrsh7th/nvim-cmp",
        opts = function(_, opts)
            opts.sources = opts.sources or {}
            table.insert(opts.sources, { name = "lazydev", group_index = 0 })
            opts.experimental = opts.experimental or {}
            opts.experimental.ghost_text = false -- Enable ghost text
            require("cmp").setup(opts)
        end,
    },
}
