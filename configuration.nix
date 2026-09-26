# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, omen-tools, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./grub.nix
      # ./limine.nix
      ./user.nix
      ./rice.nix
      ./nvidia.nix
      ./services.nix
      ./auto-update.nix
      ./hardware-configuration.nix
      ./packages/linux-omen-module/module.nix
    ];

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";
  time.hardwareClockInLocalTime = true;
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  
  # Enable the GNOME Desktop Environment (kept as failsafe session).
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

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
    wireplumber.enable = true;

    extraConfig.pipewire."50-custom.conf" = {
      # Lower the default quantum for reduced latency and crisper audio
      context.properties = {
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 64;
        "default.clock.max-quantum" = 1024;
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [ 44100 48000 96000 ];
      };

      # Clean voice / improved mic quality via echo cancellation + noise suppression
      context.modules = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Echo Cancellation source";
            "media.name" = "Echo Cancellation source";
            "filter.graph" = {
              nodes = [
                {
                  type = "ladspa";
                  name = "echo_cancel";
                  plugin = "libwebrtc_audioproc";
                  label = "echo_cancel";
                  control = {
                    "voice_detection" = 1;
                    "extended_filter" = 1;
                    "noise_suppression" = 3;
                    "high_pass_filter" = 1;
                  };
                }
              ];
            };
            "capture.props" = {
              "node.name" = "capture_echo_cancel_source";
              "node.passive" = true;
              "node.dont-reconnect" = true;
              "audio.rate" = 48000;
              "audio.position" = [ "FL" "FR" ];
              "media.class" = "Audio/Source";
            };
            "playback.props" = {
              "node.name" = "playback_echo_cancel_source";
              "node.passive" = true;
              "node.dont-reconnect" = true;
              "audio.position" = [ "FL" "FR" ];
              "media.class" = "Audio/Sink";
            };
            "audio.channels" = 2;
            "audio.rate" = 48000;
          };
        }
      ];
    };

    wireplumber.extraConfig."90-bluetooth.conf".monitor.bluez.rules = [
      {
        matches = [{ "device.name" = "~bluez_card.*"; }];
        actions = {
          "update-props" = {
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
          };
        };
      }
    ];
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  programs.nix-ld.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim wget git efibootmgr fastfetch lm_sensors nvtopPackages.full
    btop mokutil tree wl-clipboard omen-tools python3 tmux openssl
    sbctl limine-full nix-ld
  ];

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
  
  boot.tmp.cleanOnBoot = true;
  
  nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 4d"; # Deletes files from older generations
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
