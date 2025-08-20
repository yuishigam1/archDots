if true then return {} end
return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",                -- Follow the latest release.
    build = "make install_jsregexp", -- Install jsregexp for LuaSnip.
    config = function()
      require("luasnip").config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI",
      })
      require("luasnip.loaders.from_vscode").lazy_load()                                       -- Load VS Code-style snippets lazily.
      require("luasnip.loaders.from_lua").load({ paths = { "~/.config/nvim/lua/snippets/" } }) -- Load Lua snippets.
    end,
  },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = { { path = "luvit-meta/library", words = { "vim%.uv" } } },
    },
  },
  { "Bilal2453/luvit-meta", lazy = true },
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
  {
    "CRAG666/code_runner.nvim",
    config = function()
      require("code_runner").setup({
        filetype = {
          java = { "cd $dir &&", "javac $fileName &&", "java $fileNameWithoutExt" },
          python = "python3 -u",
          typescript = "deno run",
          rust = { "cd $dir &&", "rustc $fileName &&", "$dir/$fileNameWithoutExt" },
          c = function(...)
            local c_base = { "cd $dir &&", "gcc $fileName -o", "/tmp/$fileNameWithoutExt" }
            local c_exec = { "&& /tmp/$fileNameWithoutExt &&", "rm /tmp/$fileNameWithoutExt" }
            require("code_runner.commands").run_from_fn(vim.list_extend(c_base, c_exec))
          end,
          cpp = {
            "cd $dir &&",
            "g++ -std=c++20 -Wall $fileName -o /tmp/$fileNameWithoutExt",
            "&& /tmp/$fileNameWithoutExt &&",
            "rm /tmp/$fileNameWithoutExt",
          },
        },
      })
    end,
  },
  {
    "xeluxee/competitest.nvim",
    dependencies = "MunifTanjim/nui.nvim",
    config = function()
      require("competitest").setup({
        local_config_file_name = ".competitest.lua",
        floating_border = "rounded",
        floating_border_highlight = "FloatBorder",
        split_ui = {
          position = "right",
          relative_to_editor = true,
          total_width = 0.35,
          total_height = 0.6,
          vertical_layout = { { 1, "tc" }, { 1, { { 1, "so" }, { 1, "eo" } } }, { 1, { { 1, "si" }, { 1, "se" } } } },
          horizontal_layout = { { 2, "tc" }, { 3, { { 1, "so" }, { 1, "si" } } }, { 3, { { 1, "eo" }, { 1, "se" } } } },
        },
        highlight = {
          test_case = { fg = "#5f5fff", bold = true },
          output = { fg = "#87afaf" },
          error_output = { fg = "#ff5f5f" },
        },
        save_current_file = true,
        compile_directory = ".",
        compile_command = {
          c = { exec = "gcc", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
          cpp = { exec = "g++", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
          rust = { exec = "rustc", args = { "$(FNAME)" } },
          java = { exec = "javac", args = { "$(FNAME)" } },
        },
        run_command = {
          c = { exec = "./$(FNOEXT)" },
          cpp = { exec = "./$(FNOEXT)" },
          rust = { exec = "./$(FNOEXT)" },
          python = { exec = "python3", args = { "$(FNAME)" } },
          java = { exec = "java", args = { "$(FNOEXT)" } },
        },
        multiple_testing = -1,
        maximum_time = 5000,
        output_compare_method = "squish",
        view_output_diff = false,
        testcases_directory = ".",
        testcases_auto_detect_storage = true,
        testcases_single_file_format = "$(FNOEXT).testcases",
        testcases_input_file_format = "$(FNOEXT)_input$(TCNUM).txt",
        testcases_output_file_format = "$(FNOEXT)_output$(TCNUM).txt",
        companion_port = 27121,
        received_files_extension = "cpp",
        received_problems_path = "$(CWD)/$(PROBLEM).$(FEXT)",
        received_problems_prompt_path = true,
        received_contests_directory = "$(CWD)",
        received_contests_problems_path = "$(PROBLEM).$(FEXT)",
        open_received_problems = true,
        open_received_contests = true,
      })
    end,
  },
  {
    "Mofiqul/vscode.nvim",
  },

  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme gruvbox]])
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        clangd = {
          cmd = { "clangd" },
        },
      },
    },
  },
}
