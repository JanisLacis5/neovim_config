-- Basic LSP setup (C/C++ via clangd)
local lspconfig = require('lspconfig')
local capabilities = require('plugins.cmp_nvim_lsp').capabilities

local on_attach = function(_, bufnr)
  local map = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, noremap = true })
  end

  map('n', 'gd', vim.lsp.buf.definition)
  map('n', 'gD', vim.lsp.buf.declaration)
  map('n', 'gi', vim.lsp.buf.implementation)
  map('n', 'gr', vim.lsp.buf.references)
  map('n', 'K',  vim.lsp.buf.hover)
  map('n', '<leader>rn', vim.lsp.buf.rename)
  map('n', '<leader>ca', vim.lsp.buf.code_action)
  map('n', '[d', vim.diagnostic.goto_prev)
  map('n', ']d', vim.diagnostic.goto_next)
end

-- Diagnostics UI
vim.diagnostic.config({
  virtual_text = { source = "if_many" },  -- show source only if multiple (helps spot dupes)
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { source = "if_many" },
})

-- clangd (install it on your system: e.g. `sudo apt install clangd` or `brew install llvm`)
lspconfig.clangd.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  -- cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" }, -- optional flags
})

-- Python
local capabilities = require("cmp_nvim_lsp").default_capabilities()
lspconfig.pyright.setup({
    capabilities = capabilities,
})
local cmp = require("cmp")

cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
  }),
  sources = {
    { name = "nvim_lsp" },
  },
})
