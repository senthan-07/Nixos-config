# Grub Configuration
{ config, pkgs, ... }:

{
  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = false;
    grub = {
      enable = true;
      device = "nodev"; # "nodev" is used for UEFI
      efiSupport = true;
      useOSProber = true;
      configurationLimit=4;

       # This adds the custom BIOS entry to the bottom of the GRUB menu
      extraEntries = ''
        menuentry "Firmware Setup (BIOS)" --class settings {
        fwsetup
        }
      '';
    };
    efi.canTouchEfiVariables = true;
  };
}
