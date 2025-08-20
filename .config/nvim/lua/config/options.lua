vim.wo.relativenumber = false
vim.wo.number = true

vim.diagnostic.config({ virtual_text = false })

vim.api.nvim_command("autocmd FileType * setlocal formatoptions-=cro")

vim.opt.clipboard = "unnamedplus"
