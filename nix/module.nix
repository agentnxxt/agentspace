self: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.agentspace;
  inherit (lib) mkEnableOption mkOption types literalExpression;

  selectedPackage =
    if cfg.variant == "full"
    then self.packages.${pkgs.system}.agentspace-full
    else cfg.package;

  profilePathEntries = lib.optionals (cfg.pathUser != null) [
    "/home/${cfg.pathUser}/.nix-profile/bin"
    "/home/${cfg.pathUser}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${cfg.pathUser}/bin"
  ];

  servicePathEntries =
    cfg.pathPrepend
    ++ [
      "/run/wrappers/bin"
      "/nix/profile/bin"
      "/nix/var/nix/profiles/default/bin"
      "/run/current-system/sw/bin"
    ]
    ++ profilePathEntries
    ++ lib.optionals (cfg.variant == "full") ["${pkgs.chromium}/bin"]
    ++ cfg.pathAppend;
in {
  options.services.agentspace = {
    enable = mkEnableOption "Agentspace AI Agent";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.system}.agentspace;
      defaultText = literalExpression "self.packages.\${pkgs.system}.agentspace";
      description = "The Agentspace package to use (for slim variant).";
    };

    variant = mkOption {
      type = types.enum ["slim" "full"];
      default = "slim";
      description = ''
        Which variant to use:
        - slim: Core functionality, no browser tool
        - full: Includes Chromium for browser automation
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/agentspace";
      description = ''
        Directory where Agentspace stores its data, including config.toml.
        Manage config.toml directly in this directory.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "agentspace";
      description = "User account under which Agentspace runs.";
    };

    group = mkOption {
      type = types.str;
      default = "agentspace";
      description = "Group under which Agentspace runs.";
    };

    pathUser = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "alice";
      description = ''
        User whose Nix profile paths should be added to PATH for worker tools.
        When set, Agentspace includes:
          - /home/<user>/.nix-profile/bin
          - /home/<user>/.local/state/nix/profile/bin
          - /etc/profiles/per-user/<user>/bin

        Keep this null to only use system-wide Nix profile paths.
      '';
    };

    pathPrepend = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["/opt/tools/bin"];
      description = "Directories to prepend to the service PATH before built-in defaults.";
    };

    pathAppend = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["/srv/agentspace/bin"];
      description = "Directories to append to the service PATH after built-in defaults.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/agentspace/env";
      description = ''
        Path to an environment file loaded into the service.
        Useful for injecting secrets (API keys, tokens) via sops-nix or agenix
        without storing them in config.toml or the Nix store.

        Example contents:
          ANTHROPIC_API_KEY=sk-ant-...
          DISCORD_BOT_TOKEN=...
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Extra environment variables passed to the service.";
    };

    port = mkOption {
      type = types.port;
      default = 19898;
      description = "Port Agentspace listens on. Used for the firewall rule and the initial config.toml seed.";
    };

    bind = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address to bind the HTTP server to. Used for the initial config.toml seed.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the configured port in the firewall.";
    };

    hardening = mkOption {
      type = types.bool;
      default = false;
      description = "Enable systemd service hardening (sandboxing).";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = lib.mkIf (cfg.user == "agentspace") {
      inherit (cfg) group;
      isSystemUser = true;
      home = cfg.dataDir;
      description = "Agentspace daemon user";
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "agentspace") {};

    systemd.services.agentspace = {
      description = "Agentspace AI Agent";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      wants = ["network-online.target"];

      environment =
        {
          AGENTSPACE_DIR = cfg.dataDir;
          AGENTSPACE_DEPLOYMENT = "nixos";
          PATH = lib.mkForce (lib.concatStringsSep ":" servicePathEntries);
        }
        // cfg.environment;

      # Seed a minimal config.toml on first run so the web UI is reachable.
      # The user then configures everything else through the web UI.
      script = ''
        if [ ! -f "${cfg.dataDir}/config.toml" ]; then
          cat > "${cfg.dataDir}/config.toml" <<EOF
        [api]
        enabled = true
        port = ${toString cfg.port}
        bind = "${cfg.bind}"
        EOF
          chmod 600 "${cfg.dataDir}/config.toml"
        fi
        exec ${selectedPackage}/bin/agentspace start --foreground
      '';

      serviceConfig =
        {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = baseNameOf cfg.dataDir;
          StateDirectoryMode = "0750";

          Restart = "on-failure";
          RestartSec = "5s";

          EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        }
        // lib.optionalAttrs cfg.hardening {
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          SystemCallFilter = "@system-service";
          ReadWritePaths = [cfg.dataDir];
        };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
  };
}
