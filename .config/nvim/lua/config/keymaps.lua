-- Keymaps for CompetiTest
vim.api.nvim_set_keymap("n", "<leader>Cr", ":CompetiTest run<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>Ca", ":CompetiTest add_testcase<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>Ce", ":CompetiTest edit_testcase<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>Cd", ":CompetiTest delete_testcase<CR>", { noremap = true, silent = true })

-- Keymaps for Code Runner
vim.api.nvim_set_keymap("n", "<F5>", ":RunCode<CR>", { noremap = true, silent = true })

-- Disable arrow key movements
vim.api.nvim_set_keymap("n", "<Up>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Down>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Left>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Right>", "<Nop>", { noremap = true, silent = true })

-- Buffer navigation
-- vim.api.nvim_set_keymap("n", "<C-right>", ":bnext
-- vim.api.nvim_set_keymap("n", "<C-left>", ":bprevious<CR>", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("n", "<C-up>", ":bfirst<CR>", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("n", "<C-down>", ":blast<CR>", { noremap = true, silent = true })
--
--  vimtmuxnavigation
vim.api.nvim_set_keymap("n", "<C-right>", ":TmuxNavigateRight<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-left>", ":TmuxNavigateLeft<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-up>", ":TmuxNavigateUp<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-down>", ":TmuxNavigateDown<CR>", { noremap = true, silent = true })

-- Navigate splits using Shift + arrow keys
vim.api.nvim_set_keymap("n", "<S-Up>", "<C-w>k", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<S-Down>", "<C-w>j", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<S-Left>", "<C-w>h", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<S-Right>", "<C-w>l", { noremap = true, silent = true })

vim.api.nvim_set_keymap(
  "i",
  "<Tab>",
  "luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>'",
  { expr = true, silent = true }
)
vim.api.nvim_set_keymap("s", "<Tab>", "<cmd>lua require('luasnip').jump(1)<CR>", { silent = true })
vim.api.nvim_set_keymap("i", "<S-Tab>", "<cmd>lua require('luasnip').jump(-1)<CR>", { silent = true })
vim.api.nvim_set_keymap("s", "<S-Tab>", "<cmd>lua require('luasnip').jump(-1)<CR>", { silent = true })

vim.keymap.set({ "n", "v" }, "<leader>cca", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })

-- Resize window height
vim.api.nvim_set_keymap("n", "<M-Up>", ":resize +2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<M-Down>", ":resize -2<CR>", { noremap = true, silent = true })

-- Resize window width
vim.api.nvim_set_keymap("n", "<M-Left>", ":vertical resize -2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<M-Right>", ":vertical resize +2<CR>", { noremap = true, silent = true })
