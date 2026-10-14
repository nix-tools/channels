# The weekly publish, as a package rather than a workflow step: the release is cut from a
# laptop the same way CI cuts it, and the only thing .github/workflows/weekly.yml knows is
# how to install Nix and commit the index afterwards.
#
# Nix itself is deliberately not a runtime input. The script calls the nix that invoked it,
# which is the one whose daemon and caches it must agree with.
{
  perSystem =
    { pkgs, ... }:
    {
      packages.publish = pkgs.writeShellApplication {
        name = "publish";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gh
          git
          jq
          xz
          zstd
        ];
        text = builtins.readFile ./publish.sh;
      };
    };
}
