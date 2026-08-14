{ config, lib, pkgs, ... }:

{
  # ==========================================================================
  # Zed 编辑器：本体由 pacman 管理（package = null 只托管配置，见 AGENTS.md：
  # Nix 版与系统 GL 栈不兼容）。
  #
  # mutableUserSettings 默认开启：settings.json 是真实文件（不是 store 符号链接），
  # zed 内部可以自己改（如换主题），switch 时声明式设置合并回去覆盖同名键。
  # ==========================================================================
  programs.zed-editor = {
    enable = true;
    package = null;

    userSettings = {
      # 遥测全关
      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 16;

      theme = {
        mode = "dark";
        light = "One Light";
        dark = "One Dark";
      };

      remove_trailing_whitespace_on_save = false;   # 有意保留，勿动
      ensure_final_newline_on_save = true;
    };
  };

  # ==========================================================================
  # Neovim：programs.neovim 声明式托管（本体 + 插件全部来自 nixpkgs，版本由
  # flake.lock 锁定）。EDITOR/VISUAL 已在 fish 里指向 nvim。
  #
  #   - 插件：catppuccin 主题 / treesitter(全部 grammar) / lspconfig / mason /
  #           cmp 补全 / telescope 查找 / which-key / gitsigns
  #   - LSP server：mason 运行时安装到 ~/.local/share/nvim/mason（非声明式，
  #     图省事；需要严格声明式时再迁 extraPackages）
  #   - 改配置 = 改这里 + switch，init.lua 是 store 只读链接不要手改
  # ==========================================================================
  programs.neovim = {
    enable = true;

    plugins = with pkgs.vimPlugins; [
      catppuccin-nvim
      (nvim-treesitter.withAllGrammars)   # 全部语法高亮 grammar（store 内，不需 :TSInstall）
      nvim-lspconfig
      mason-nvim
      mason-lspconfig-nvim
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp_luasnip
      luasnip
      telescope-nvim
      which-key-nvim
      gitsigns-nvim
    ];

    initLua = ''
      -- 基础选项
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 4
      vim.opt.tabstop = 4
      vim.opt.smartindent = true
      vim.opt.termguicolors = true
      vim.opt.clipboard = "unnamedplus"
      vim.opt.undofile = true
      vim.opt.scrolloff = 8
      vim.opt.signcolumn = "yes"
      vim.opt.mouse = "a"
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.g.mapleader = " "

      -- 主题
      require("catppuccin").setup({ flavour = "mocha", transparent_background = false })
      vim.cmd.colorscheme("catppuccin")

      -- 语法高亮（nvim-treesitter 0.9.2+ 顶层 API，grammars 由 nix 提供）
      require("nvim-treesitter").setup({
        highlight = { enable = true },
        indent = { enable = true },
      })

      -- 快捷键总览
      require("which-key").setup({})

      -- LSP：mason 安装 server，lspconfig 按 filetype 接入
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "bashls", "pyright", "gopls", "rust-analyzer", "clangd", "jsonls", "yamlls", "marksman" },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then return end
          local opts = { buffer = args.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, opts)
        end,
      })

      -- 补全
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args) require("luasnip").lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif require("luasnip").expand_or_jumpable() then require("luasnip").expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })

      -- 查找
      require("telescope").setup({})
      vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<CR>")
      vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<CR>")
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<CR>")
      vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<CR>")

      -- git 迹象（jj 仓库也是 git 仓库）
      require("gitsigns").setup({})
    '';
  };

  # ==========================================================================
  # Helix：先装个试试（本体 nixpkgs 25.07，配置声明式）
  # ==========================================================================
  programs.helix = {
    enable = true;
    settings = {
      theme = "catppuccin_mocha";
      editor = {
        line-number = "relative";
        cursorline = true;
        bufferline = "multiple";
      };
    };
  };
}
