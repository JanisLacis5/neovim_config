local cmp = require("cmp")
local luasnip = require("luasnip")

-- Use your custom dir
vim.g.UltiSnipsSnippetDirectories = {
  vim.fn.expand("~/.config/nvim/lua/plugins/ultisnips")
}

-- Kill UltiSnips’ own <Tab> mappings so they don’t fight cmp
vim.g.UltiSnipsExpandTrigger = "<Nop>"
vim.g.UltiSnipsJumpForwardTrigger = "<Nop>"
vim.g.UltiSnipsJumpBackwardTrigger = "<Nop>"

local function in_tex() return vim.bo.filetype == "tex" end

cmp.setup({
  snippet = {
    expand = function(args)
      if in_tex() then
        vim.fn["UltiSnips#Anon"](args.body)
      else
        luasnip.lsp_expand(args.body)
      end
    end,
  },
  preselect = cmp.PreselectMode.Item,
  mapping = cmp.mapping.preset.insert({
    ["<CR>"] = cmp.mapping.confirm({ select = true }),

    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        -- choose and confirm on Tab (one key like your experimental)
        cmp.confirm({ select = true })
        return
      end
      if in_tex() then
        if vim.fn["UltiSnips#CanExpandSnippet"]() == 1
           or vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
          vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
            "<C-R>=UltiSnips#ExpandSnippetOrJump()<CR>", true, true, true
          ), "")
          return
        end
      end
      if luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
        return
      end
      fallback()
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
        return
      end
      if in_tex() and vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
          "<C-R>=UltiSnips#JumpBackwards()<CR>", true, true, true
        ), "")
        return
      end
      if luasnip.jumpable(-1) then
        luasnip.jump(-1)
        return
      end
      fallback()
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "path" },
    { name = "buffer" },
    { name = "luasnip" },   -- default
  }),
})

-- Prefer UltiSnips suggestions in TeX menus
cmp.setup.filetype("tex", {
  sources = cmp.config.sources({
    { name = "ultisnips" },
    { name = "buffer" },
    { name = "path" },
  }),
})
