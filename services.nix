{ config, pkgs, ... }:

{
  # Sleep configuration
  systemd.sleep.settings = {
    Sleep = {
      AllowSuspend = "yes";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };
  };

  # Lid close -> Suspend
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "suspend";

    # Ignore the hibernate key
    HandleHibernateKey = "ignore";
  };

  # Disable hibernate-related targets
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  #Warp
  services.cloudflare-warp.enable = true;
  
  # Docker is configured but does NOT start automatically at boot.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  #DDCUTIL
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", MODE="0660", GROUP="video"
  '';

  environment.etc."local/bin/brightness" = {
    source = ./scripts/brightness;
    mode = "0755";
  };
}