{ config, lib, ... }:

with lib;

let
  cfg = config.services.knix;
in
{
  options.services.knix.multus = mkOption {
    type = types.submodule {
      options = {
        enable = mkEnableOption "Multus CNI meta-plugin" // {
          default = true;
        };

        extraConfig = mkOption {
          type = types.attrsOf types.raw;
          default = { };
          description = "Extra config merged into the multus HelmChartConfig valuesContent";
        };
      };
    };
    default = { };
    description = "multus addon settings";
  };

  config = mkIf cfg.multus.enable {
    services.knix = {
      # Multus must be the first CNI plugin so it can delegate to canal
      extraConfig = mkIf (cfg.role == "server") {
        cni = mkBefore [
          "multus"
        ];
      };

      manifests.rke2-multus-config = {
        content = {
          apiVersion = "helm.cattle.io/v1";
          kind = "HelmChartConfig";
          metadata = {
            name = "rke2-multus";
            namespace = "kube-system";
          };
          spec.valuesContent = recursiveUpdate {
            # Multus meta-plugin + Whereabouts IPAM. Gives selected pods a second
            # interface on the LAN bridge (br0) for local-network exposure (e.g. Jellyfin UPnP).
            rke2-whereabouts.enabled = true;
          } cfg.multus.extraConfig;
        };
      };
    };
  };
}
