let
  envConfig = builtins.getEnv "NODE_CONFIG";
  nodeConfig = if envConfig == "" then
    import ./configs/default.nix
  else
    import envConfig;
in
  { nixpkgs ? <nixpkgs>
  , configuration ? nodeConfig
  , vpsadmin
  , system ? builtins.currentSystem }:
  let
    pkgs = import nixpkgs { inherit system; config = {}; };

    baseModules = [
      ./base.nix
      ./nixos-compat.nix
      ./modules/vpsadmin/core/node/default.nix
      <nixpkgs/nixos/modules/misc/nixpkgs.nix>
    ];

    pkgsModule = rec {
      _file = ./default.nix;
      key = _file;
      config = {
        nixpkgs.system = pkgs.lib.mkDefault system;
        nixpkgs.overlays = import ./overlays { inherit vpsadmin; };
      };
    };

    evalConfig = modules: pkgs.lib.evalModules {
      prefix = [];
      check = true;
      modules = modules ++ baseModules ++ [ pkgsModule ];
      args = {};
    };

    result = evalConfig (if configuration != null then [configuration] else []);

  in rec {
    config = result.config;
  }
