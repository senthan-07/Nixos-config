# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

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
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  #Omen
  boot.extraModulePackages = [ hpomen ];
  boot.blacklistedKernelModules = [ "hp_wmi" ];
  boot.kernelModules = [ "hpomen" "ec_sys" ];
 
  # flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_IN";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # Use the WirePlumber session manager
    #wireplumber.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."senthan" = {
    isNormalUser = true;
    description = "Senthan";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;


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

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
   environment.systemPackages = with pkgs; [
     vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
     wget
     efibootmgr
     vscode
     btop
     brave
     git
     gh
     gnome-extension-manager
     gnomeExtensions.clipboard-indicator
     kitty
     python3
     fan_speed
     omenfan
     fan_max
     tree
     ec_read
   ];

   fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
   ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
