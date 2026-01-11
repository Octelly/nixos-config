{ pkgs, ... }:
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    extraPlugins = with pkgs.vimPlugins; [
      sonokai # theme
      moonscript-vim # language support
      (pkgs.vimUtils.buildVimPlugin {
        # syncs terminal background with theme background (OSC11)
        # NOTE: does not change opacity on Wezterm
        pname = "bg.nvim";
        version = "2024-12-16";

        src = pkgs.fetchFromGitHub {
          owner = "typicode";
          repo = "bg.nvim";
          rev = "df916e4df2493ee302eea62185ed014ba7ca40d9";
          hash = "sha256-H+ZFX0hE9te6qo+fzUuWngHOEf0zGyHkEIQIYvyTzTI=";
        };
      })
      (pkgs.vimUtils.buildVimPlugin {
        # syntax highlight for jrnl.sh
        pname = "jrnl.vim";
        version = "2024-07-23";

        src = pkgs.fetchFromGitHub {
          owner = "wren";
          repo = "jrnl.vim";
          rev = "4cde7e66d19a7b0a0bb00e0ffc02f3ddb24519ac";
          hash = "sha256-XL+O/2j7rDNT4mylD8/vX2r/9RVoMRijmIPZaoiCqow=";
        };
      })
    ];

    globals = {
      # Sonokai has multiple styles
      sonokai_style = "shusia";

      sonokai_enable_italic = true;

      # substitution live preview
      inccomand = "nosplit";

      # WARNING: blah blah this is experimental
      #          if you encounter issues, disable this
      cmdheight = 0;
    };

    colorscheme = "sonokai";

    opts = {
      # relative line numbers
      number = true;
      relativenumber = true;

      # wrapped lines continue with same indentation on next line
      breakindent = true;

      # save undo history
      undofile = true;

      # case-insensitive search unless specified
      ignorecase = true;
      smartcase = true;

      # generally enables mouse stuff
      mouse = "a";

      # use system clipboard
      clipboard = "unnamedplus";

      # decrease update time
      updatetime = 250;

      # minimum margin lines around cursor
      scrolloff = 5;

      # mode is shown in lualine
      showmode = false;

      # linebreak so that words aren't split when wrapped
      linebreak = true;

      # visible whitespace characters
      list = true;
      listchars = {
        tab = "» ";
        trail = "·";
      };
    };

    extraConfigLua = ''
      -- font to be used in GUIs such as Neovide
      vim.o.guifont = "Maple Mono NF:h12"

      -- check if Neovide options are available
      if vim.g.neovide then
        vim.g.neovide_hide_mouse_when_typing = true
        vim.g.neovide_remember_window_size = true
        vim.g.neovide_cursor_animate_in_insert_mode = false
        vim.g.neovide_cursor_vfx_mode = "railgun"
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'jrnl',
        callback = function ()
          vim.schedule(function ()
            require("zen-mode").open({
              window = {
                width = 78,
                options = {
                  signcolumn = "no",
                  number = false,
                  relativenumber = false,
                  cursorcolumn = false,
                  foldcolumn = "0"
                }
              }
            })
            vim.o.foldenable = false
          end)
        end,
      })
    '';

    # https://editorconfig.org/
    editorconfig.enable = true;

    keymaps =
      let
        mkRaw = x: { __raw = x; };
      in
      [
        # exit terminal mode with 2x escape
        # (default keybind is something esoteric and weird)
        {
          key = "<Esc><Esc>";
          action = "<C-\\><C-n>";
          mode = "t";
        }

        # smart-splits
        # (see plugin explanation later in the config)
        {
          mode = "n";
          key = "<S-Left>";
          action = mkRaw "require('smart-splits').move_cursor_left";
          options.silent = true;
        }
        {
          mode = "n";
          key = "<S-Down>";
          action = mkRaw "require('smart-splits').move_cursor_down";
          options.silent = true;
        }
        {
          mode = "n";
          key = "<S-Up>";
          action = mkRaw "require('smart-splits').move_cursor_up";
          options.silent = true;
        }
        {
          mode = "n";
          key = "<S-Right>";
          action = mkRaw "require('smart-splits').move_cursor_right";
          options.silent = true;
        }

        {
          mode = "n";
          key = "<A-Left>";
          action = mkRaw "require('smart-splits').resize_left";
          options.silent = true;
        }
        {
          mode = "n";
          key = "<A-Down>";
          action = mkRaw "require('smart-splits').resize_down";
          options.silent = true;
        }
        {
          mode = "n";
          key = "<A-Up>";
          action = mkRaw "require('smart-splits').resize_up";
          options.silent = true;
        }
        {
          mode = "n";
          key = "<A-Right>";
          action = mkRaw "require('smart-splits').resize_right";
          options.silent = true;
        }

      ];

    plugins = rec {

      lsp = {
        enable = true;
        servers = {
          # JSON
          jsonls.enable = true;

          # Nix
          nil_ls = {
            enable = true;
            extraOptions = {
              formatting.command = "${pkgs.nixpkgs-fmt}";
            };
          };

          # LUA
          #lua_ls.enable = true;
          emmylua_ls.enable = true;

          # Python
          #pyright.enable = true;
          ruff.enable = true;
          ty.enable = true;

          # Svelte
          svelte.enable = true;

          # JS/TS
          ts_ls.enable = true;

          # Docker
          docker_language_server.enable = true;

          # Typst
          tinymist.enable = true;
        };
      };

      # formatting provided by LSPs
      lsp-format.enable = true;

      # pictograms for LSP completions
      lspkind = {
        enable = true;
        cmp.enable = cmp.enable;
      };

      # Typst live preview
      typst-preview.enable = true;

      # better splits with support for wez, kitty, tmux
      smart-splits = {
        enable = true;
      };

      # used for JRNL.sh
      zen-mode.enable = true;

      # pretty diagnostics, references, quickfixes, etc.
      trouble.enable = true;

      # detect tab/spaces and width
      sleuth.enable = true;

      # better code understanding - code tree
      treesitter = {
        enable = true;

        # use tresitter as fold method
        folding = true;
      };

      # keep definition of nested functions and such pinned on top
      treesitter-context = {
        enable = true;
        settings = rec {
          max_lines = 6;
          min_window_height = 3 * max_lines;
        };
      };

      # smart rename + some extras
      treesitter-refactor = {
        enable = true;
        highlightDefinitions.enable = true;

        # bound to 'grr' by default
        smartRename.enable = true;
      };

      # colour preview
      colorizer = {
        enable = true;
        settings.user_default_options = {
          mode = "virtualtext";
          virtualtext_inline = true;
        };
      };

      # see project directory (cd into project with :cd)
      nvim-tree = {
        enable = true;

        settings = {
          sync_root_with_cwd = true;

          # colours are enough imo
          renderer.icons.show.git = false;
        };
      };

      # see open buffers in a tab-like UI
      bufferline = {
        enable = true;
        settings.options.offsets = [
          {
            filetype = "NvimTree";
            text = "meow~ :3";
            highlight = "Directory";
            separator = true;
          }
        ];
      };

      # add a scrollbar
      scrollview = {
        enable = true;
        settings.signs_on_startup = [ "all" ];
      };

      # icons provider for nvim-tree, trouble and other plugins
      web-devicons.enable = true;

      # a lua powered greeter like vim-startify / dashboard-nvim
      alpha = {
        enable = true;
        layout = [
          {
            type = "text";
            val = [
              "hello gays welcome to my nixvim config"
              ""
              "⠀⠀⠀⢰⠶⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠶⠲⣄⠀"
              "⠀⠀⣠⡟⠀⠈⠙⢦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⡶⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠾⠋⠁⠀⠀⢽⡄"
              "⠀⠀⡿⠀⠀⠀⠀⠀⠉⠷⣄⣀⣤⠤⠤⠤⠤⢤⣷⡀⠙⢷⡄⠀⠀⠀⠀⣠⠞⠉⠀⠀⠀⠀⠀⠈⡇"
              "⠀⢰⡇⠀⠀⠀⠀⠀⠀⠀⠉⠳⣄⠀⠀⠀⠀⠀⠈⠁⠀⠀⠹⣦⠀⣠⡞⠁⠀⠀⠀⠀⠀⠀⠀⠀⡗"
              "⠀⣾⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣻⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣏"
              "⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡇"
              "⠀⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⠂"
              "⠀⢿⠀⠀⠀⠀⣤⣤⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣤⣤⣤⣤⡀⠀⠀⠀⠀⠀⣸⠇⠀"
              "⠀⠘⣇⠀⠀⠀⠀⠉⠉⠛⠛⢿⣶⣦⠀⠀⠀⠀⠀⠀⢴⣾⣟⣛⡋⠋⠉⠉⠁⠀⠀⠀⠀⣴⠏⠀⠀"
              "⢀⣀⠙⢷⡄⠀⠀⣀⣤⣶⣾⠿⠋⠁⠀⢴⠶⠶⠄⠀⠀⠉⠙⠻⠿⣿⣷⣶⡄⠀⠀⡴⠾⠛⠛⣹⠇"
              "⢸⡍⠉⠉⠉⠀⠀⠈⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⣬⠷⣆⣠⡤⠄⢀⣤⠞⠁⠀"
              "⠈⠻⣆⡀⠶⢻⣇⡴⠖⠀⠀⠀⣴⡀⣀⡴⠚⠳⠦⣤⣤⠾⠀⠀⠀⠀⠀⠘⠟⠋⠀⠀⠀⢻⣄⠀⠀"
              "⠀⠀⣼⠃⠀⠀⠉⠁⠀⠀⠀⠀⠈⠉⢻⡆⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⠀⠀"
              "⠀⢠⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡀⠀⠀⢀⡇⠀⠀⠀⠀⠀⠀⠀⠀⣀⡿⠧⠿⠿⠟⠀⠀"
              "⠀⣾⡴⠖⠛⠳⢦⣿⣶⣄⣀⠀⠀⠀⠀⠘⢷⣀⠀⣸⠃⠀⠀⠀⣀⣀⣤⠶⠚⠉⠀⠀⠀⠀⠀⠀⠀"
              "⠀⠀⠀⠀⠀⠀⠀⠈⢷⡀⠈⠻⠦⠀⠀⠀⠀⠉⠉⠁⠀⠀⠀⠀⠹⣆⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
              "⠀⠀⠀⠀⠀⠀⠀⢀⡴⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢳⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀"
              "⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠻⡄⠀⠀⠀⠀⠀⠀⠀⠀"
              "⠀⠀⠀⠀⠀⠀⠈⠉⠛⠛⢲⡗⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡆⠀⠀⠀⠀⠀⠀⠀"
              "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀"
              "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠋⠀⠀⠀⠀⠀⠀⠀"
              ""
              "this is a read-only buffer, sorry"
            ];
          }
        ];
      };

      # completions and integrations
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings.sources = [
          { name = "nvim_lsp"; }
          { name = "nvim_lsp_document_symbol"; }
          { name = "nvim_lsp_signature_help"; }
          { name = "path"; }
          { name = "treesitter"; }
        ];
      };

      # UI framework of sorts that some plugins hook into
      fidget.enable = true;

      # bottom statusline
      lualine = {
        enable = true;

        settings = {
          sections = {
            lualine_x = [
              "searchcount"
              "filetype"
            ];
          };

          options = {
            globalstatus = true;

            sectionSeparators = {
              left = "";
              right = "";
            };
            componentSeparators = {
              left = "";
              right = "";
            };
          };
        };
      };
    };
  };
}
