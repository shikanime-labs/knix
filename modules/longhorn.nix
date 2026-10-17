{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.knix;
in
{
  options.services.knix.addons.longhorn = mkOption {
    type = types.submodule {
      options = {
        enable = mkEnableOption "Longhorn addon" // {
          default = true;
        };

        mountRoot = mkOption {
          type = types.str;
          default = "/mnt";
          description = "The mount root scanned for additional Longhorn disks";
        };

        storageReservedPercentageForDefaultDisk = mkOption {
          type = types.int;
          default = 30;
          description = "The percentage of disk space reserved on the default /var/lib/longhorn/ disk";
        };
      };
    };
    default = { };
    description = "Longhorn addon settings";
  };

  config = mkIf cfg.addons.longhorn.enable {
    boot = {
      kernelModules = [
        "dm_crypt"
        "iscsi_tcp"
      ];

      supportedFilesystems = [ "nfs" ];
    };

    environment.systemPackages = with pkgs; [
      cryptsetup
      lvm2
      nfs-utils
      openiscsi
    ];

    networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts =
      let
        longhornMetricsPort = 9099;
      in
      [ longhornMetricsPort ];

    services = {
      knix.labels."node.longhorn.io/create-default-disk" = "config";

      openiscsi = {
        enable = true;
        name = "iqn.2026-06.io.shikanime:${config.networking.hostName}";
      };
    };

    systemd = {
      tmpfiles.rules = [
        "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
      ];
    };
  };
}
