{ config, lib, pkgs, ... }:
let

  # The main hostname of the system, also used for network ID
  hostName = "box";

  # Setup UPS auto poweroff
  clientScript = pkgs.writeShellScript "client-script" ''
    case $1 in
      on-batt)
        ${pkgs.util-linux}/bin/logger -t upssched-cmd "UPS On Battery state exceeded timer value."
        ${pkgs.systemd}/bin/shutdown now
        ;;
      *)
        ${pkgs.util-linux}/bin/logger -t upssched-cmd "UPS Unrecognized event: $1"
        ;;
    esac
  '';

  path = "/var/lib/nut";
  
  # UPS Scheduler Configuration
  clientSched = pkgs.writeText "client-schedule" ''
    CMDSCRIPT ${clientScript}

    PIPEFN ${path}/upssched.pipe
    LOCKFN ${path}/upssched.lock

    AT ONBATT * START-TIMER on-batt 60
    AT ONLINE * CANCEL-TIMER on-batt
  '';

  # Shared Configurations
  sharedConf = {
    # User to run
    RUN_AS_USER = "root";
    # Binaries
    SHUTDOWNCMD = "${pkgs.systemd}/bin/shutdown now";
    # Number of power supplies before shutting down
    MINSUPPLIES = 1;
    # Query intervals
    POLLFREQ = 1;
    POLLFREQALERT = 1;
    # Debug
    # DEBUG_MIN = 9;
  };

  # Default Notify
  defaultNotify = "SYSLOG+EXEC";

  # Map Notify Flags
  mapNotifyFlags = listTypes: notification:
    map (each: [ each notification ]) listTypes;


in
{
  imports =
    [ 
      # Import nixos-hardware
      "${builtins.fetchGit { url = "https://github.com/NIXOS/nixos-hardware.git"; }}/acer/predator/helios/300/ph315-51"

      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # UPS client
  power.ups = {

    enable = true;
    mode = "netclient";
    schedulerRules = "${clientSched}";

    # UPS Monitor
    upsmon = {

      # Connection
      monitor.main = {
        system = "apc@router";
        powerValue = 1;
        user = "admin";
        passwordFile = "/home/lakituen/secrets/ups-pass.txt";
        type = "secondary";
      };

      # Settings
      settings = sharedConf // {
        # Binary Scheduler
        NOTIFYCMD = "${pkgs.nut}/bin/upssched";
        # Flags to be notified
        NOTIFYFLAG = mapNotifyFlags [
          "ONLINE" "ONBATT"
        ] defaultNotify;
      };

    };

  };

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

