{
  perSystem =
    { config, ... }:
    {
      devshells.default.packages = [ config.packages.publish ];
    };
}
