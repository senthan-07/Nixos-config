{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  patchelfUnstable,

  gtk3,
  alsa-lib,
  adwaita-icon-theme,
  dbus-glib,
  libXtst,

  curl,
  libva,
  pciutils,
  pipewire,

  version,
  url,
  hash,

  ...
}:

stdenv.mkDerivation {
  pname = "zen-browser-unwrapped";
  inherit version;

  src = fetchurl {
    inherit url hash;
  };

  nativeBuildInputs = [
    wrapGAppsHook3
    autoPatchelfHook
    patchelfUnstable
  ];

  buildInputs = [
    gtk3
    alsa-lib
    adwaita-icon-theme
    dbus-glib
    libXtst
  ];

  runtimeDependencies = [
    curl
    libva
    pciutils
  ];

  appendRunpaths = [
    "${pipewire}/lib"
  ];

  installPhase = ''
    mkdir -p "$out/lib/zen-${version}"

    cp -r . "$out/lib/zen-${version}/"

    mkdir -p "$out/bin"

    ln -s \
      "$out/lib/zen-${version}/zen" \
      "$out/bin/zen"
  '';

  passthru = {
    inherit version gtk3;

    applicationName = "Zen Browser";
    binaryName = "zen";
    libName = "zen-${version}";
  };

  patchelfFlags = [
    "--no-clobber-old-sections"
  ];

  meta = {
    mainProgram = "zen";
    description = "Zen Browser";
  };
}
