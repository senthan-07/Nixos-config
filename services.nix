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
}