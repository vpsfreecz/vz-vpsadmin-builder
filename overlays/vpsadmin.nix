vpsadmin: self: super:
{
  vpsadmin.core.node = { ... }@args:
    super.beam.packages.erlangR21.callPackage "${vpsadmin}/packages/core/generic.nix" args;
}
