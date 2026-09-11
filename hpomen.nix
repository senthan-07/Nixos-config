{ lib
, stdenv
, kernel
, linux-omen-module
}:

stdenv.mkDerivation {
  pname = "hpomen";
  version = "1.0";

  src = linux-omen-module + "/hpomen-1.0";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KVERSION=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
    cp hpomen.ko $out/lib/modules/${kernel.modDirVersion}/extra/
  '';

  meta = {
    description = "HP OMEN WMI driver";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}