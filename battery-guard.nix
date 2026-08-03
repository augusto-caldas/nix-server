{ pkgs, ... }:

let
  batteryGuardScript = pkgs.writeShellScriptBin "battery-guard" ''
    # Detect primary battery path
    BAT_DIR=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)

    if [ -z "$BAT_DIR" ]; then
      echo "No battery detected."
      exit 0
    fi

    STATUS=$(cat "$BAT_DIR/status")
    CAPACITY=$(cat "$BAT_DIR/capacity")

    # Check if discharging and battery level is 30% or lower
    if [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le 30 ]; then
      echo "Low battery ($CAPACITY%) detected while discharging! Stopping Docker containers..."
      
      # Stop running docker containers with a 10-second timeout
      CONTAINERS=$(${pkgs.docker}/bin/docker ps -q)
      if [ -n "$CONTAINERS" ]; then
        ${pkgs.docker}/bin/docker stop $CONTAINERS
      fi

      echo "Powering off system..."
      ${pkgs.systemd}/bin/systemctl poweroff
    fi
  '';
in
{
  # Define the systemd service
  systemd.services.battery-guard = {
    description = "Stop Docker containers and power off if battery falls below 30%";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${batteryGuardScript}/bin/battery-guard";
    };
    path = [ pkgs.docker pkgs.systemd pkgs.coreutils ];
  };

  # Define the systemd timer to run every 2 minutes
  systemd.timers.battery-guard = {
    description = "Timer for low battery guard check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "2m";
      Unit = "battery-guard.service";
    };
  };
}
