{ config, pkgs, lib, linux-omen-module, ... }:

let
  hpomen =
    config.boot.kernelPackages.callPackage ./hpomen.nix {
      inherit linux-omen-module;
    };

  omen-tools =
    pkgs.callPackage ./tools.nix {
      inherit linux-omen-module;
    };
in
{
  # HP OMEN kernel module
  boot.extraModulePackages = [
    hpomen
  ];

  boot.kernelModules = [
    "hpomen"
    "ec_sys"
  ];

  # Disable the stock HP WMI driver
  boot.blacklistedKernelModules = [
    "hp_wmi"
  ];

  # /usr/local/bin
  systemd.tmpfiles.rules = [
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/fan_max - - - - ${omen-tools}/bin/fan_max"
    "L+ /usr/local/bin/fan_speed - - - - ${omen-tools}/bin/fan_speed"
    "L+ /usr/local/bin/ec_read - - - - ${omen-tools}/bin/ec_read"
    "L+ /usr/local/bin/Omenfan - - - - ${omen-tools}/bin/Omenfan"
    "L+ /usr/local/bin/Omenhsa - - - - ${omen-tools}/bin/Omenhsa"
  ];

  # Services
  systemd.services.Omenfan = {
    description = "HP OMEN Fan Control";

    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "/usr/local/bin/Omenfan";
      Restart = "on-failure";
    };
  };

  systemd.services.Omenhsaclient = {
    description = "HP OMEN HSA Client";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/usr/local/bin/Omenhsa";
    };
  };

  # systemd.timers.Omenhsaclient = {
  #   description = "Run HP OMEN HSA Client periodically";

  #   wantedBy = [ "timers.target" ];

  #   timerConfig = {
  #     Unit = "Omenhsaclient.service";
  #     OnBootSec = "10s";
  #     OnUnitInactiveSec = "110s";
  #     AccuracySec = "3s";
  #   };
  # };
}