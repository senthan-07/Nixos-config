final: prev:

{
  opencode =
    let
      bun_1_3_13 = prev.bun.overrideAttrs (old: rec {
        version = "1.3.13";

        src = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-${
            {
              "x86_64-linux" = "linux-x64-baseline";
              "aarch64-linux" = "linux-aarch64";
              "aarch64-darwin" = "darwin-aarch64";
            }.${final.system}
          }.zip";

          hash = {
            "x86_64-linux" = "sha256-nYokKSpwaAkCBdqsCloiP19pc29Sh+N7+I07QDHtx1A=";
          }.${final.system};
        };
      });
    in

    prev.opencode.override {
      bun = bun_1_3_13;
    };
}