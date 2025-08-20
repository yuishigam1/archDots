return {
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
}
