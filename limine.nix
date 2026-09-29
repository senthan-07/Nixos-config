# limine bootloader
{ config, pkgs, ... }:

{
# In your environment packages add limine-full and sbctl if not all ready added
# environment.systemPackages = with pkgs; [ limine-full sbctl ];

# if you get an error, you may not yet have keys generated or are not in setup mode.
# First run the command
# sudo sbctl create-keys

# Next we need to enter your BIOs or UEFI and set secure boot to setup mode, once it is in setup mode go back into your nixos install and 
# run the command  
# sudo sbctl enroll-keys --microsoft
# sudo nixos-rebuild switch

# to make your keys the --microsoft flag is required to make keys compatible with microsoft windows. Reboot again and secure boot should now work properly, you can check your EFI signed status by running 
# sudo sbctl verify
# all the microsoft entries should be not signed. if needed sign these, or any other EFI entries you need signed.
# sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
# sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi

  boot.loader = {
    systemd-boot.enable = false;
    limine ={
      enable = true;
      efiSupport = true;
      # efiInstallAsRemovable = true;
      secureBoot.enable = false; 
      enrollConfig = true;
      panicOnChecksumMismatch = true;
      maxGenerations = 5;

      extraEntries = ''
        /Windows 11
          comment: Windows Boot Manager
          protocol: efi
          path: uuid(72936cd4-2cee-488b-890b-ce45c1a08808):/EFI/Microsoft/Boot/bootmgfw.efi
      '';
      extraConfig = ''
        timeout: 15
      '';

    };
    efi.canTouchEfiVariables = true;
  };

  # Catppuccin colours for the Limine menu (catppuccin/nix flake input).
  # `enable` turns the module on; `autoEnable = false` stops it from also
  # theming everything else (cursors, GTK icons, TTY…), which rice/matugen and
  # Bibata already handle. Flavour defaults to mocha: catppuccin.flavor/accent.
  catppuccin = {
    enable = true;
    autoEnable = false;
    limine.enable = true;
  };
}
