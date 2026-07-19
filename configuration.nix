{ config, lib, pkgs, ... }:
let

  # The main hostname of the system, also used for network ID
  hostName = "box";

in
{
  imports =
    [ 
      # Import nixos-hardware
      "${builtins.fetchGit { url = "https://github.com/NIXOS/nixos-hardware.git"; }}/acer/predator/helios/300/ph315-51"

      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Configure ZFS
  boot.zfs.forceImportRoot = false;

  # Define hostname
  networking.hostName = hostName;
  networking.hostId = builtins.substring 0 8 (builtins.hashString "sha512" hostName);

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Dublin";

  # Ignore lid close
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  
  # Define user account.
  users.users.lakituen = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "libvirtd" ]; # Enable 'sudo' for the user.
    shell = pkgs.fish;
    packages = with pkgs; [
      docker-compose
      dmidecode
      fastfetch
      git
      htop
      tmux
      tree
      wget
    ];
  };

  # Setup unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg: 
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "nvidia-kernel-modules"
  ];

  # Enable firmware update
  services.fwupd.enable = true;

  # Setup fish shell
  programs.fish.enable = true;
  environment.shells = with pkgs; [ fish ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Setup docker
  virtualisation.docker.enable = true;

  # Version system was installed
  system.stateVersion = "26.05";

}

