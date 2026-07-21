{ pkgs, lib, config, ... }:

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
    extraPackages = [ pkgs.ast-grep ];
    settings = {
      permission = {
        "*" = "ask";
        bash = {
          # WARN: ORDER MATTERS! The first matching rule will be applied.
          "free *" = "allow";
          "git blame *" = "allow";
          "git diff *" = "allow";
          "git grep *" = "allow";
          "git log *" = "allow";
          "git ls-files *" = "allow";
          "git rev-parse *" = "allow";
          "git show *" = "allow";
          "git status *" = "allow";
          "halt *" = "deny";
          "journalctl -u *" = "allow";
          "loginctl *" = "deny";
          "lsblk *" = "allow";
          "lscpu *" = "allow";
          "lsmod *" = "allow";
          "lspci *" = "allow";
          "machinectl *" = "deny";
          "modinfo *" = "allow";
          "mount *" = "deny";
          "mount" = "allow";
          "nh os *" = "deny";
          "nix * --impure *" = "deny";
          "nix eval *" = "allow";
          "nix flake info *" = "allow";
          "nix flake metadata *" = "allow";
          "nix flake show *" = "allow";
          "nix path-info *" = "allow";
          "nix profile *" = "deny";
          "nix store path-from-hash-part *" = "allow";
          "nix why-depends *" = "allow";
          "nix-env *" = "deny";
          "nixos-rebuild *" = "deny";
          "nproc *" = "allow";
          "pkexec *" = "deny";
          "polkit *" = "deny";
          "poweroff *" = "deny";
          "reboot *" = "deny";
          "shutdown *" = "deny";
          "sudo *" = "deny";
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
          "systemd-run *" = "deny";
          "umount *" = "deny";
          "uname *" = "allow";
          "head *" = "allow";
          "tail *" = "allow";
          "baloosearch6 *" = "allow";
          "balooshow6 *" = "allow";
          "balooctl6 status" = "allow";
          "kreadconfig6 *" = "allow";
          "loginctl show-session *" = "allow";
          "busctl tree *" = "allow";
          "busctl introspect *" = "allow";
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
