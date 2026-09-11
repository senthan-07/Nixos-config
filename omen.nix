{ config, pkgs, linux-omen-module, ... }:

let
  hpomen = pkgs.callPackage ./hpomen.nix {
    kernel = config.boot.kernelPackages.kernel;
    inherit linux-omen-module;
  };

  fan_speed = pkgs.writeShellApplication {
    name = "fan_speed";
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "Usage: fan_speed <hex_value>  (e.g., fan_speed 0x14)"
        exit 1
      fi

      hex_value="$1"

      if [[ ! "$hex_value" =~ ^0x[0-9A-Fa-f]+$ ]]; then
        echo "Error: '$hex_value' is not a valid hexadecimal number (e.g., 0x14)"
        exit 1
      fi

      echo "$hex_value" > /sys/devices/platform/hp-wmi/fanspeed
    '';
  };

  omenfan = pkgs.writeScriptBin "Omenfan" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./Omenfan.py}
  '';

  omenhsa = pkgs.writeShellApplication {
    name = "Omenhsa";
    text = ''
      cat /sys/devices/platform/hp-wmi/fancount > /dev/null
    '';
  };

  fan_max = pkgs.writeShellApplication {
    name = "fan_max";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "Usage: fan_max <1 or 0>"
        exit 1
      fi

      fan_control="$1"

      if [ "$fan_control" -eq 1 ]; then
        echo 0 | sudo tee /sys/devices/platform/hp-wmi/hwmon/hwmon*/pwm1_enable > /dev/null
        sudo systemctl stop Omenfan.service

      elif [ "$fan_control" -eq 0 ]; then
        echo 2 | sudo tee /sys/devices/platform/hp-wmi/hwmon/hwmon*/pwm1_enable > /dev/null
        sudo systemctl start Omenfan.service

      else
        echo "Invalid input. Please use 1 for max fan speed or 0 for automatic mode."
        exit 2
      fi
    '';
  };

  ec_read = pkgs.writeScriptBin "ec_read" ''
    #!${pkgs.python3}/bin/python3

    import os

    ECIO_FILE = "/sys/kernel/debug/ec/ec0/io"

    if os.geteuid() != 0:
        print("Error: this script requires root privileges (run via sudo or as root).")
        raise SystemExit(1)

    if not os.path.exists(ECIO_FILE):
        print(f"Error: EC interface not available: {ECIO_FILE}")
        raise SystemExit(1)

    try:
        with open(ECIO_FILE, "rb") as ec:
            data = ec.read()
    except PermissionError:
        print(f"Error: permission denied accessing {ECIO_FILE}")
        raise SystemExit(1)

    if len(data) < 256:
        print("Warning: Data length is less than expected (256 bytes).")
        raise SystemExit(1)

    BLUE = "\033[94m"
    WHITE = "\033[0m"

    c = 0

    for i in range(16):
        for j in range(16):
            byte_value = data[c]

            if byte_value != 0:
                print(f"{BLUE}0x{byte_value:02x}{WHITE}", end=" ")
            else:
                print(f"0x{byte_value:02x}", end=" ")

            c += 1

        print()
  '';
in
{
  boot.extraModulePackages = [ hpomen ];

  boot.blacklistedKernelModules = [ "hp_wmi" ];

  boot.kernelModules = [
    "hpomen"
    "ec_sys"
  ];

  systemd.services.Omenfan = {
    description = "HP Omen automatic fan control";

    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${omenfan}/bin/Omenfan";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  systemd.services.Omenhsaclient = {
    description = "Omenhsa Client Service";

    after = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${omenhsa}/bin/Omenhsa";
    };
  };

  systemd.timers.Omenhsaclient = {
    description = "Run Omenhsa Client Service periodically";

    wantedBy = [ "timers.target" ];

    timerConfig = {
      Unit = "Omenhsaclient.service";
      OnBootSec = "1s";
      OnUnitInactiveSec = "110s";
      AccuracySec = "3s";
    };
  };

  environment.systemPackages = [
    fan_speed
    omenfan
    fan_max
    ec_read
  ];
}