--------------------------------------------------
-- Basic Neovim Configuration
-- Created: 2025-05-27
--------------------------------------------------

-- General Settings
vim.opt.number = true          -- Show line numbers
vim.opt.relativenumber = true  -- Show relative line numbers
vim.opt.mouse = 'a'            -- Enable mouse support in all modes
vim.opt.clipboard = 'unnamedplus' -- Use system clipboard
vim.opt.cursorline = true      -- Highlight current line
vim.opt.termguicolors = true   -- Enable 24-bit RGB colors
vim.opt.showmode = false       -- Don't show mode (e.g., -- INSERT --)
vim.opt.showcmd = true         -- Show command in bottom bar
vim.opt.cmdheight = 1          -- Height of the command bar
vim.opt.incsearch = true       -- Shows the match while typing
vim.opt.hlsearch = true        -- Highlight search results
vim.opt.ignorecase = true      -- Ignore case when searching
vim.opt.smartcase = true       -- Override ignorecase if search pattern has uppercase
vim.opt.splitright = true      -- Split vertical windows to the right
vim.opt.splitbelow = true      -- Split horizontal windows below
vim.opt.wrap = false           -- Don't wrap lines by default
vim.opt.scrolloff = 8          -- Keep 8 lines above/below cursor when scrolling
vim.opt.sidescrolloff = 8      -- Keep 8 columns left/right of cursor when scrolling
vim.opt.fileencoding = 'utf-8' -- Use UTF-8 encoding
vim.opt.backup = false         -- Don't create backup files
vim.opt.writebackup = false    -- Don't create temporary backup during write
vim.opt.swapfile = false       -- Don't create swap files
vim.opt.updatetime = 300       -- Faster completion
vim.opt.timeoutlen = 500       -- Timeout for mapped sequences (ms)

-- Indentation Settings
vim.opt.expandtab = true       -- Use spaces instead of tabs
vim.opt.shiftwidth = 2         -- Number of spaces for each indentation level
vim.opt.tabstop = 2            -- Number of spaces a tab counts for
vim.opt.softtabstop = 2        -- Number of spaces a tab counts for while editing
vim.opt.smartindent = true     -- Smart auto-indenting when starting a new line
vim.opt.autoindent = true      -- Copy indent from current line when starting a new line

-- UI Configuration
vim.opt.signcolumn = 'yes'     -- Always show the sign column (for diagnostics)
vim.opt.colorcolumn = '80'     -- Show column at 80 characters
vim.opt.list = true            -- Show invisible characters
vim.opt.listchars = {          -- How to show invisible characters
  tab = ' ',
  trail = '',
  extends = '',
  precedes = '',
  nbsp = ''
}

-- Key Mappings
vim.g.mapleader = ' '          -- Set leader key to space

-- Better window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', { noremap = true, silent = true })
vim.keymap.set('n', '<C-j>', '<C-w>j', { noremap = true, silent = true })
vim.keymap.set('n', '<C-k>', '<C-w>k', { noremap = true, silent = true })
vim.keymap.set('n', '<C-l>', '<C-w>l', { noremap = true, silent = true })

-- Resize with arrows
vim.keymap.set('n', '<C-Up>', ':resize -2<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-Down>', ':resize +2<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-Left>', ':vertical resize -2<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-Right>', ':vertical resize +2<CR>', { noremap = true, silent = true })

-- Clear search highlighting with Escape
vim.keymap.set('n', '<Esc>', ':noh<CR>', { noremap = true, silent = true })

-- Navigate buffers
vim.keymap.set('n', '<S-l>', ':bnext<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<S-h>', ':bprevious<CR>', { noremap = true, silent = true })

-- Stay in indent mode when indenting in visual mode
vim.keymap.set('v', '<', '<gv', { noremap = true, silent = true })
vim.keymap.set('v', '>', '>gv', { noremap = true, silent = true })

-- Don't lose selection when shifting sidewards
vim.keymap.set('x', '<S-h>', '<gv', { noremap = true, silent = true })
vim.keymap.set('x', '<S-l>', '>gv', { noremap = true, silent = true })

-- Enable syntax highlighting
vim.cmd [[
  syntax enable
  colorscheme desert
]]

-- Automatically highlight yanked text
vim.api.nvim_create_autocmd('TextYankPost', {
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 150 })
  end
})

-- Enable auto-saving when text changes or leaving insert mode
vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
  pattern = '*',
  command = 'silent! update',
})

-- Auto-reload files when changed externally
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
  pattern = '*',
  command = 'if mode() != "c" | checktime | endif',
})
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  pattern = '*',
  command = 'echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None',
})

print("Basic Neovim configuration loaded successfully!")

