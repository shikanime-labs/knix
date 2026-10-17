{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.services.knix;
in
{
  options.services.knix.prometheus = mkOption {
    type = types.submodule {
      options.enable = mkEnableOption "prometheus addon" // {
        default = true;
      };
    };
    default = { };
    description = "prometheus settings";
  };

  config = mkIf cfg.prometheus.enable {
    services.knix.extraConfig = {
      # Expose controller manager for prometheus to scrape metrics
      kube-controller-manager-arg = [ "bind-address=0.0.0.0" ];
      # Expose scheduler for prometheus to scrape metrics
      kube-scheduler-arg = [ "bind-address=0.0.0.0" ];
      # Enable RKE2 supervisor metrics
      supervisor-metrics = true;
    };
  };
}
