{ pkgs, ... }:

let
  # packages/source.json is the single source of truth: every top-level key
  # that defines both 'repo' and 'asset' is auto-tracked. Adding a future
  # wrapper = add an entry there, a boot-time update timer is created for it
  # automatically.
  sources = builtins.fromJSON (builtins.readFile ./packages/source.json);

  trackable = builtins.filter (k: (sources.${k} ? repo) && (sources.${k} ? asset))
    (builtins.attrNames sources);

  mkService = key: {
    name = "${key}-update";
    value = {
      description = "Check for new ${key} release";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "senthan";
        WorkingDirectory = "/etc/nixos";
        Environment = "HOME=/home/senthan";
        ExecStart =
          "${pkgs.bash}/bin/bash /etc/nixos/scripts/update-sources.sh ${key}";
      };
      path = [ pkgs.curl pkgs.python3 pkgs.nix pkgs.coreutils ];
    };
  };

  mkTimer = key: {
    name = "${key}-update";
    value = {
      description = "Check for ${key} updates at each boot";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "${key}-update.service";
        OnBootSec = "10min";
        AccuracySec = "1min";
      };
    };
  };
in
{
  systemd.services = builtins.listToAttrs (map mkService trackable);
  systemd.timers = builtins.listToAttrs (map mkTimer trackable);
}
