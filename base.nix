{ pkgs, lib, ... }:
with lib;
{
  options = {
    system.build = mkOption {
      internal = true;
      default = {};
      description = "Attribute set of derivations used to setup the system.";
    };
  };

  config = {};
}
