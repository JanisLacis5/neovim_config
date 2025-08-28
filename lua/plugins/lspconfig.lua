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

-- If classic "pyright" ever attaches alongside basedpyright, stop it to avoid duplicates.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "pyright" then
      client.stop()
    end
  end,
})

-- Optional: if nvim-lint is present, disable Python there to avoid a third diagnostic source
pcall(function()
  local lint = require('lint')
  lint.linters_by_ft = vim.tbl_extend('force', lint.linters_by_ft or {}, { python = {} })
end)

-- clangd (install it on your system: e.g. `sudo apt install clangd` or `brew install llvm`)
lspconfig.clangd.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  -- cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" }, -- optional flags
})

-- ──────────────────────────────────────────────────────────────────────────────
-- Mason + LSP servers
-- ──────────────────────────────────────────────────────────────────────────────
local mason = require("mason")
local mason_lsp = require("mason-lspconfig")
local cmp_caps = require("cmp_nvim_lsp").default_capabilities()
local util = require("lspconfig.util")

mason.setup()
mason_lsp.setup({
  ensure_installed = {
    -- Python
    "basedpyright",   -- or "pyright"
    "ruff",           -- ruff-lsp
    -- JS/TS
    "vtsls",
    "eslint",
  }
})

-- ──────────────────────────────────────────────────────────────────────────────
-- PYTHON: robust venv detection (VIRTUAL_ENV, .venv/venv/.env, Poetry)
-- Also configures both modern (venvPath/venv) and legacy (pythonPath) fields.
-- ──────────────────────────────────────────────────────────────────────────────
local function join(...) return table.concat({ ... }, "/") end

local function detect_venv(workspace)
  -- 1) Active shell venv
  local ve = os.getenv("VIRTUAL_ENV")
  if ve and #ve > 0 and vim.fn.executable(join(ve, "bin", "python")) == 1 then
    -- venvPath: parent dir of the venv folder; venv: folder name
    return ve, vim.fn.fnamemodify(ve, ":h"), vim.fn.fnamemodify(ve, ":t")
  end
  -- 2) Project-local folders
  for _, name in ipairs({ ".venv", "venv", ".env" }) do
    local py = join(workspace, name, "bin", "python")
    if vim.fn.executable(py) == 1 then
      return join(workspace, name), workspace, name
    end
  end
  -- 3) Poetry (best effort)
  if vim.fn.executable("poetry") == 1 then
    local p = vim.fn.systemlist({ "poetry", "env", "info", "-p" })[1]
    if p and #p > 0 and vim.fn.executable(join(p, "bin", "python")) == 1 then
      -- venv likely outside workspace
      return p, vim.fn.fnamemodify(p, ":h"), vim.fn.fnamemodify(p, ":t")
    end
  end
  -- 4) Fallback: no venv
  return "", "", ""
end

local function py_settings(root)
  local venv_abs, venvPath, venvName = detect_venv(root)
  local interp = (venv_abs ~= "" and join(venv_abs, "bin", "python")) or (vim.fn.exepath("python3") or "python3")

  -- optional toast so you can see what it picked
  vim.schedule(function()
    vim.notify(("Pyright interpreter: %s"):format(interp), vim.log.levels.INFO)
  end)

  return {
    python = {
      venvPath = (venvPath ~= "" and venvPath or root), -- where venv folder lives
      venv = (venvName ~= "" and venvName or nil),      -- venv folder name, e.g. "venv"
      pythonPath = interp,               -- legacy/compat
      defaultInterpreterPath = interp,   -- some clients use this
      analysis = {
        autoImportCompletions = true,
        diagnosticMode = "workspace",
        typeCheckingMode = "standard",
        -- Hand off "unused ..." style checks to Ruff to avoid duplicated messages:
        diagnosticSeverityOverrides = {
          reportUnusedImport   = "none",
          reportUnusedVariable = "none",
          -- You can also disable these if Ruff handles them:
          -- reportUnusedFunction = "none",
          -- reportUnusedClass    = "none",
        },
        -- If you import from repo root (e.g., `from app...`), uncomment:
        -- extraPaths = { root },
      },
    },
  }
end

-- basedpyright (or swap to lspconfig.pyright with same config)
lspconfig.basedpyright.setup({
  capabilities = cmp_caps,
  on_attach = on_attach,
  root_dir = util.root_pattern(
    "pyrightconfig.json",
    "pyproject.toml",
    "requirements.txt",
    "setup.py",
    "setup.cfg",
    ".git"
  ),
  before_init = function(_, config)
    local root = config.root_dir or vim.loop.cwd()
    config.settings = py_settings(root)
  end,
})

-- Ruff (diagnostics & quick-fixes for Python)
lspconfig.ruff.setup({
  capabilities = cmp_caps,
  on_attach = on_attach,
  init_options = { settings = { args = {} } },
})

-- ──────────────────────────────────────────────────────────────────────────────
-- JavaScript / TypeScript via vtsls
-- ──────────────────────────────────────────────────────────────────────────────
lspconfig.vtsls.setup({
  capabilities = cmp_caps,
  on_attach = on_attach,
  root_dir = util.root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git"),
  settings = {
    typescript = {
      format = { semicolons = "insert" },
      preferences = {
        importModuleSpecifier = "non-relative",
        quoteStyle = "single",
      }
    },
    javascript = {
      preferences = { quoteStyle = "single" },
    },
    vtsls = {
      tsserver = { maxTsServerMemory = 3072 },
      experimental = { completion = { enableServerSideFuzzyMatch = true } },
    },
  },
})

-- ESLint (optional but recommended with JS/TS projects)
lspconfig.eslint.setup({
  capabilities = cmp_caps,
  on_attach = on_attach,
  root_dir = util.root_pattern(".eslintrc*", "package.json", ".git"),
})
