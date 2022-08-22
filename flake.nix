{
  description = "Discord GMod Bot";

  inputs = {
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        nodejs = pkgs.nodejs;
        out = pkgs.callPackage ./default.nix { inherit system pkgs nodejs; };
        discord_gmod_bot = pkgs.writeShellScriptBin "discord_gmod_bot" ''
          exec ${nodejs}/bin/node ${out.package}/lib/node_modules/discord_gmod_bot
        '';
      in
      rec {
        packages = { inherit discord_gmod_bot; };
        packages.default = discord_gmod_bot;
        apps.default = flake-utils.lib.mkApp { drv = discord_gmod_bot; };
        overlay = _: _: packages;
      }))
    // {
      nixosModules.default = { lib, config, pkgs, ... }:
        let
          inherit (lib) mkOption types mkIf;
          name = "discord_gmod_bot";
          ports = [ 37405 ];
          cfg = config.services.${name};
          boolToIntStr = b: if b then "1" else "0";
          envFile = pkgs.writeText ".env" (''
            API_KEY=${cfg.API_KEY}
            DEBUG=${boolToIntStr cfg.DEBUG}
            DISCORD_TOKEN=${cfg.DISCORD_TOKEN}
            DISCORD_CHANNEL=${cfg.DISCORD_CHANNEL}
            DISCORD_GUILD=${cfg.DISCORD_GUILD}
            KEEPALIVE_ENABLED=${boolToIntStr cfg.KEEPALIVE_ENABLED}
            KEEPALIVE_HOST=${cfg.KEEPALIVE_HOST}
            KEEPALIVE_PORT=${builtins.toString cfg.KEEPALIVE_PORT}
          '' + cfg.extraEnv);
        in
        {
          options.services.${name} = {
            enable = mkOption { type = types.bool; default = false; };
            autostart = mkOption { type = types.bool; default = true; };
            extraEnv = mkOption { type = types.str; default = ""; };
            stateDir = mkOption { type = types.str; default = name; };
            API_KEY = mkOption { type = types.uniq types.str; };
            DEBUG = mkOption { type = types.bool; default = false; };
            DISCORD_TOKEN = mkOption { type = types.uniq types.str; };
            DISCORD_CHANNEL = mkOption { type = types.uniq types.str; };
            DISCORD_GUILD = mkOption { type = types.uniq types.str; };
            KEEPALIVE_ENABLED = mkOption { type = types.bool; default = false; };
            KEEPALIVE_HOST = mkOption { type = types.uniq types.str; default = "localhost"; };
            KEEPALIVE_PORT = mkOption { type = types.uniq types.int; default = 443; };
          };
          config = mkIf cfg.enable {
            systemd.services.${name} = {
              description = "Discord GMod Bot";
              # TODO https://www.freedesktop.org/software/systemd/man/systemd-socket-proxyd.html
              wantedBy = if cfg.autostart then [ "multi-user.target" ] else [ ];
              after = [ "network.target" ];

              serviceConfig = {
                ExecStart = "${pkgs.discord_gmod_bot}/bin/discord_gmod_bot";
                WorkingDirectory = "/var/lib/${cfg.stateDir}";
                DynamicUser = true;
                StateDirectory = cfg.stateDir;
                Restart = "always";
                RestartSec = 20;
              };

              preStart = ''
                ln -sf ${envFile} .env
              '';
            };

            networking.firewall.allowedUDPPorts = ports;
            networking.firewall.allowedTCPPorts = ports;
          };
        };
      # yeah ik this is hacky but it works... (really wish home-manager and nixos were more consistent)
      homeModules.default = { lib, config, pkgs, ... }@args:
        let
          inherit (lib) mkOption types mkIf;
          name = "discord_gmod_bot";
          cfg = config.services.${name};
          nixosConfig = self.nixosModule args;
          nixosToHomeService = name: service: {
            Unit.Description = service.description;
            Unit.After = service.after;
            Install.WantedBy = service.wantedBy;
            Service = service.serviceConfig // {
              ExecStartPre = "${pkgs.writeShellScript "unit-script-${name}-pre-start" service.preStart}";
              WorkingDirectory = "${config.xdg.configHome}/${cfg.stateDir}";
            };
          };
        in
        (removeAttrs nixosConfig [ "config" ]) // {
          config = mkIf cfg.enable {
            systemd.user.services.${name} = nixosToHomeService name nixosConfig.config.content.systemd.services.${name};
          };
        };
    };
}
