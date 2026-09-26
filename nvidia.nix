{ config, lib, pkgs, modulesPath, ... }:

{
  # Configure the NVIDIA driver
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    open = true; # Use the open-source kernel module
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      # Use the Bus IDs you found earlier
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

}