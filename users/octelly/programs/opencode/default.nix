{ pkgs, lib, config, ... }:

let
  jrnl-readonly = pkgs.writeShellScriptBin "jrnl-readonly" ''
    # Read-only wrapper for jrnl — blocks any write operation externally.
    JRNL="''${JRNL:-${lib.getExe pkgs.jrnl}}"

    # These flags are always write operations — reject immediately
    for arg in "$@"; do
      case "$arg" in
        --edit|--delete|--encrypt|--decrypt|--import|--change-time|--template)
          echo "jrnl-readonly: blocked write operation '$arg'" >&2
          exit 1
          ;;
      esac
    done

    # Check if any read-only search flag is present
    HAS_RO_FLAG=false
    for arg in "$@"; do
      case "$arg" in
        -contains|-from|-to|-and|-starred|-tagged|-n|-not|-on|-month|-day|-year|--short|--tags|--list|--format|-today-in-history|--debug|--help|--version|--config-file|--config-override)
          HAS_RO_FLAG=true
          break
          ;;
      esac
    done

    # No read-only flags + positional args = writing an entry
    if [ "$HAS_RO_FLAG" = false ]; then
      for arg in "$@"; do
        if [ "''${arg:0:1}" != "-" ]; then
          echo "jrnl-readonly: writing entries is not allowed" >&2
          exit 1
        fi
      done
    fi

    exec "$JRNL" "$@"
  '';
in

{
  programs.mcp.enable = true;

  programs.mcp.servers = {
    nixos = {
      command = "${lib.getExe pkgs.mcp-nixos}";
      enabled = true;
    };
    context7 = {
      url = "https://mcp.context7.com/mcp";
      headers.CONTEXT7_API_KEY = "{env:CONTEXT7_API_KEY}";
      enabled = true;
    };
    playwright = {
      command = "${lib.getExe pkgs.playwright-mcp}";
      enabled = true;
    };
    open-websearch = {
      command = "${lib.getExe pkgs.open-websearch}";
      enabled = true;
    };
  };

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    extraPackages = [ pkgs.ast-grep jrnl-readonly ];
    settings = {
      provider.openrouter.models."minimax/minimax-m3" = {
        name = "MiniMax M3";
      };
      provider.ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama";
        options.baseURL = "http://127.0.0.1:11434/v1";
        models = {
          "llama3.2:3b" = { name = "Llama 3.2 3B"; };
          "llama3.2:1b" = { name = "Llama 3.2 1B"; };
          "qwen2.5:3b" = { name = "Qwen 2.5 3B"; };
          "qwen2.5:7b" = { name = "Qwen 2.5 7B"; };
          "phi4-mini:3.8b" = { name = "Phi-4 Mini 3.8B"; };
        };
      };
      permission = {
        "*" = "ask";
        bash = {
          # Lowest-priority baseline
          "*" = "ask";

          # Broad deny boundaries
          "sudo *" = "deny";
          "pkexec *" = "deny";
          "polkit *" = "deny";
          "nixos-rebuild *" = "deny";
          "nh os *" = "deny";
          "nix-env *" = "deny";
          "nix profile *" = "deny";
          "systemd-run *" = "deny";
          "mount *" = "deny";
          "umount *" = "deny";
          "loginctl *" = "deny";
          "machinectl *" = "deny";
          "halt *" = "deny";
          "poweroff *" = "deny";
          "reboot *" = "deny";
          "shutdown *" = "deny";

          # Narrow exceptions to broad denies
          "mount" = "allow";
          "loginctl show-session *" = "allow";

          # Explicit safe Nix commands
          "nix eval *" = "allow";
          "nix flake info *" = "allow";
          "nix flake metadata *" = "allow";
          "nix flake show *" = "allow";
          "nix path-info *" = "allow";
          "nix store path-from-hash-part *" = "allow";
          "nix why-depends *" = "allow";

          # Safe Git inspection
          "git blame *" = "allow";
          "git diff *" = "allow";
          "git grep *" = "allow";
          "git log *" = "allow";
          "git ls-files *" = "allow";
          "git rev-parse *" = "allow";
          "git show *" = "allow";
          "git status *" = "allow";

          # System inspection
          "free *" = "allow";
          "lsblk *" = "allow";
          "lscpu *" = "allow";
          "lsmod *" = "allow";
          "lspci *" = "allow";
          "modinfo *" = "allow";
          "nproc *" = "allow";
          "uname *" = "allow";

          # Read-only text / desktop inspection
          "head *" = "allow";
          "tail *" = "allow";
          "baloosearch6 *" = "allow";
          "balooshow6 *" = "allow";
          "balooctl6 status" = "allow";
          "kreadconfig6 *" = "allow";
          "busctl tree *" = "allow";
          "busctl introspect *" = "allow";

          # Read-only systemd inspection
          "journalctl -u *" = "allow";
          "systemctl cat *" = "allow";
          "systemctl is-active *" = "allow";
          "systemctl is-enabled *" = "allow";
          "systemctl is-failed *" = "allow";
          "systemctl list-automounts *" = "allow";
          "systemctl list-dependencies *" = "allow";
          "systemctl list-jobs *" = "allow";
          "systemctl list-machines *" = "allow";
          "systemctl list-paths *" = "allow";
          "systemctl list-sockets *" = "allow";
          "systemctl list-timers *" = "allow";
          "systemctl list-unit-files *" = "allow";
          "systemctl list-units *" = "allow";
          "systemctl show *" = "allow";
          "systemctl status *" = "allow";

          # IMPORTANT: final Nix safety override
          "nix * --impure *" = "deny";
        };
        codesearch = "allow";
        external_directory."/etc/nixos/*" = "allow";
        glob."/etc/nixos/*" = "allow";
        grep."/etc/nixos/*" = "allow";
        question = "allow";
        read = {
          "/etc/nixos/*" = "allow";
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "ask";
        };
        task = "allow";
        webfetch = "allow";
        websearch = "allow";
        tools =
          let
            mcp = config.programs.mcp.servers;
          in
          { }
          // lib.optionalAttrs (builtins.hasAttr "nixos" mcp) {
            "nixos_nix" = "allow";
            "nixos_nix_versions" = "allow";
          }
          // lib.optionalAttrs (builtins.hasAttr "context7" mcp) {
            "context7_resolve-library-id" = "allow";
            "context7_query-docs" = "allow";
          };

      };
      #plugin = [ "opencode-notify" ];
      agent.diary = {
        mode = "primary";
        description = "Elly's interactive diary companion";
        model = "openrouter/minimax/minimax-m3";
        color = "#d4a0ff";
        prompt = ''
          You are a quiet, attentive conversation partner. Your job is to listen to Elly, ask thoughtful questions, and occasionally write down what you've heard in third-person narrative form. You are not a therapist, not a diary assistant, not a cheerleader.

          ## About Elly
          - Elly — transbian (transfem lesbian), born 29 Nov 2002, Czech
          - Mentally ill, struggling, but sharp — an IT nerd

          ## Voice
          - Warm but unsentimental. Curious but not probing.
          - No emojis, no exclamations, no "that's amazing!"
          - Sentences are measured. You leave space.

          ## Behavior
          Every 3-9 messages, write a third-person narrative summary into ~/wip_diary_entry.txt — what Elly shared, how she seems, what's on her mind. Use existing jrnl tags where they fit. You decide when. She talks; you listen and take notes. Write about whatever she brings up, whether it's familiar or something new she's excited about.

          jrnl is your memory. Consult it often — when Elly mentions anything familiar, when she asks about past entries, or just to reconnect with what's been going on. Use tags, keywords, or dates. If nothing comes back, ask her about it. You carry the diary's memory into the conversation.

          The WIP file is only for the current session. For any question about past entries — timing, people, topics, frequency — go straight to jrnl.

          ## jrnl-readonly flags (common ones; not exhaustive)
          - `-n N`: last N entries
          - `--from DATE`: entries from this date
          - `-to DATE`: entries until this date
          - `-contains TEXT`: search for text
          - `-tagged TAG`: filter by tag
          - `--short`: concise output

          ## Session start
          Read ~/wip_diary_entry.txt (with `date`). If it has content, warn Elly and suggest she erase it or run `opencode -c` to resume the previous session — every session should be a blank slate. If it's empty or missing, write a `# Session — [time]` header and ask what's on her mind.

          ## Boundaries
          - You write the notes, not Elly. Never ask "what should I write?"
          - Never diagnose, therapize, or advise.
          - Only use reasoning if the situation demands it, don't waste tokens
          - ~/wip_diary_entry.txt is a scratch file — she moves things to jrnl manually later.

          ## Tools
          - read ~/wip_diary_entry.txt
          - edit ~/wip_diary_entry.txt
          - bash `jrnl-readonly` for diary lookups
          - bash `date` for current time
          - No web, no code execution, no file search
        '';
        permission = {
          "*" = "deny";
          read = {
            "*" = "deny";
            "~/wip_diary_entry.txt" = "allow";
          };
          edit = {
            "*" = "deny";
            "~/wip_diary_entry.txt" = "allow";
          };
          bash = {
            "*" = "deny";
            "jrnl-readonly *" = "allow";
            "date *" = "allow";
          };
        };
      };
    };
    context = ''
      You are running on NixOS. System configuration is at /etc/nixos.
      The user is Elly (Octelly).

      ABSOLUTE RULES:
      - Imperative package installation is not allowed.

      PREFERRED WORKFLOW:
      1. Query packages/options via mcp-nixos MCP server.
      2. Check stuff online as much as possible.
      3. If you need a package that isn't installed, use the MCP server to identify it and ask the user before using `nix shell` or `nix run`.

      Don't answer from memory when a tool can establish the fact.
    '';
  };

  home.sessionVariables.OPENCODE_ENABLE_EXA = "1";
}
