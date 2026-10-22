{ config, lib, ... }:

with lib;

let
  cfg = config.services.knix;
in
{
  options.services.knix.coredns = mkOption {
    type = types.submodule {
      options = {
        enable = mkEnableOption "CoreDNS node caching" // {
          default = true;
        };

        metrics = mkOption {
          type = types.submodule {
            options = {
              enable = mkEnableOption "CoreDNS metrics (prometheus endpoint + scrape)" // {
                default = true;
              };

              scrapeAddress = mkOption {
                type = types.str;
                default = "rke2-coredns-metrics.kube-system.svc:9153";
                description = "Target the prometheus scrape config hits for coredns metrics";
              };
            };
          };
          default = { };
          description = "Metrics exposure for the coredns addon";
        };

        extraConfig = mkOption {
          type = types.attrsOf types.raw;
          default = { };
          description = "Extra config merged into the coredns HelmChartConfig valuesContent";
        };
      };
    };
    default = { };
    description = "CoreDNS settings";
  };

  config = mkIf cfg.coredns.enable {
    services.knix = {
      extraConfig.disable = mkIf (!cfg.coredns.enable) [ "rke2-coredns" ];

      manifests.rke2-coredns-config.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChartConfig";
        metadata = {
          name = "rke2-coredns";
          namespace = "kube-system";
        };
        spec.valuesContent = builtins.toJSON (
          recursiveUpdate {
            nodelocal.enabled = true;
            prometheus.service.enabled = cfg.coredns.metrics.enable;
          } cfg.coredns.extraConfig
        );
      };

      # The rke2 default-network-dns-policy allows only port 53 ingress to
      # kube-dns pods, which blackholes the 9153 metrics scrape. Allow the
      # metrics port explicitly; DNS (53) stays locked by the rke2 policy.
      manifests.rke2-coredns-metrics.content = mkIf cfg.coredns.metrics.enable {
        apiVersion = "networking.k8s.io/v1";
        kind = "NetworkPolicy";
        metadata = {
          name = "coredns-metrics-ingress";
          namespace = "kube-system";
        };
        spec = {
          policyTypes = [ "Ingress" ];
          podSelector.matchLabels."k8s-app" = "kube-dns";
          ingress = [
            {
              ports = [
                {
                  port = 9153;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };

      prometheus.extraScrapeConfigs = mkIf (cfg.coredns.metrics.enable && cfg.prometheus.enable) [
        {
          job_name = "core-dns";
          scheme = "http";
          metrics_path = "/metrics";
          static_configs = [ { targets = [ cfg.coredns.metrics.scrapeAddress ]; } ];
        }
      ];

    };
  };
}
