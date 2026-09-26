{
  lib,
  stdenv,
  python3,
  bash,
  linux-omen-module,
}:

stdenv.mkDerivation {
  pname = "linux-omen-tools";
  version = "1.0";

  src = linux-omen-module;

  nativeBuildInputs = [
    python3
    bash
  ];

  dontBuild = true;

  postPatch = ''
    patchShebangs .
  '';

  installPhase = ''
    mkdir -p $out/bin

    install -Dm755 bin/fan_max $out/bin/fan_max
    install -Dm755 bin/fan_speed $out/bin/fan_speed
    install -Dm755 bin/ec_read $out/bin/ec_read
    install -Dm755 bin/Omenfan $out/bin/Omenfan
    install -Dm755 bin/Omenhsa $out/bin/Omenhsa
  '';

  meta = {
    description = "HP OMEN userspace tools";
    homepage = "https://github.com/Sharwesh05/linux-omen-module";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}