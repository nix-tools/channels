{ inputs, ... }:
{
  imports = [ inputs.dendritic-base.flakeModules.default ];

  dendritic-base.root = ../.;
}
