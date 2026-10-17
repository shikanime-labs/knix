{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.knix;

  mkAutoDeployChart =
    chart:
    let
      baseChart = removeAttrs chart [ "failurePolicy" ];
    in
    if chart.failurePolicy == null then
      baseChart
    else
      baseChart
      // {
        extraFieldDefinitions = (baseChart.extraFieldDefinitions or { }) // {
          spec.failurePolicy = chart.failurePolicy;
        };
      };

  mkExtraFlags =
    attrs:
    concatLists (
      mapAttrsToList (
        name: value:
        if value == true then
          [ "--${name}" ]
        else if builtins.isList value then
          map (v: "--${name}=${toString v}") value
        else
          [ "--${name}=${toString value}" ]
      ) attrs
    );

  scrapeConfigs = [
    {
      job_name = "kube-etcd";
      scheme = "http";
      metrics_path = "/metrics";
      static_configs = [ { targets = [ "127.0.0.1:2381" ]; } ];
    }
    {
      job_name = "kube-proxy";
      scheme = "http";
      metrics_path = "/metrics";
      static_configs = [ { targets = [ "127.0.0.1:10249" ]; } ];
    }
  ];
in
{
  config = mkIf (cfg.enable && cfg.role == "server") (mkMerge [
    {
      networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts =
        let
          rke2ApiServerPort = 6443;
          rke2SupervisorPort = 9345;
          rke2EtcdClientPort = 2379;
          rke2EtcdPeerPort = 2380;
          rke2EtcdMetricsPort = 2381;
        in
        [
          rke2ApiServerPort
          rke2SupervisorPort
          rke2EtcdClientPort
          rke2EtcdPeerPort
          rke2EtcdMetricsPort
        ];

      services = {
        knix.extraConfig = {
          cluster-cidr = [
            cfg.clusterCidr
            cfg.clusterCidrIPv6
          ];
          ingress-controller = "none";
          kube-controller-manager-arg = [
            "node-cidr-mask-size-ipv4=${toString cfg.nodeCidrMaskSize}"
            "node-cidr-mask-size-ipv6=${toString cfg.nodeCidrMaskSizeIPv6}"
          ];
          service-cidr = cfg.serviceCidr;
          secrets-encryption = true;
        };

        rke2 = {
          autoDeployCharts = mapAttrs (_: mkAutoDeployChart) cfg.charts;
          extraFlags = mkExtraFlags cfg.extraConfig;
          manifests = cfg.manifests;
        };
      };
    }

    (mkIf cfg.prometheus.enable {
      services = {
        prometheus = {
          inherit scrapeConfigs;
        };

        vmagent.prometheusConfig = {
          scrape_configs = scrapeConfigs;
        };
      };
    })

    (mkIf cfg.addons.longhorn.enable {
      systemd.services.rke2-longhorn-default-disks-config = {
        description = "Apply Longhorn default-disks-config annotation";
        wants = [ "rke2-server.service" ];
        after = [ "rke2-server.service" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";
          MOUNT_ROOT = cfg.addons.longhorn.mountRoot;
          STORAGE_RESERVED_PERCENTAGE_FOR_DEFAULT_DISK = toString cfg.addons.longhorn.storageReservedPercentageForDefaultDisk;
        };
        serviceConfig.Type = "oneshot";
        preStart = ''
          until ${pkgs.kubectl}/bin/kubectl get node ${config.networking.hostName} >/dev/null 2>&1; do
            sleep 1
          done
        '';
        script = ''
          disk_source() {
            mount_path="$1"

              ${pkgs.util-linux}/bin/findmnt -n -o SOURCE --target "$mount_path" 2>/dev/null \
                | ${pkgs.coreutils}/bin/tail -n 1 || true
            }

            disk_tags() {
              mount_path="$1"
              source="$(disk_source "$mount_path")"

              rotational="$(${pkgs.util-linux}/bin/lsblk -ndo ROTA "$source" 2>/dev/null \
                | ${pkgs.coreutils}/bin/head -n 1 \
                | ${pkgs.gnused}/bin/sed 's/[[:space:]]//g')"

              if [ -z "$rotational" ]; then
                return 1
              elif [ "$rotational" = "1" ]; then
                printf '%s\n' '["nearline"]'
              else
                printf '%s\n' '["standard"]'
              fi
            }

            storage_reserved() {
              mount_path="$1"
              storage_reserved_percent="$2"

              size="$(${pkgs.coreutils}/bin/df -B1 --output=size "$mount_path" \
                | ${pkgs.coreutils}/bin/tail -n 1 \
                | ${pkgs.gnused}/bin/sed 's/[[:space:]]//g')"
              printf '%s\n' "$((size * storage_reserved_percent / 100))"
            }

            default_disk_config_entry() {
              mount_path="$1"
              storage_reserved_percent="$2"

              if ! ${pkgs.util-linux}/bin/mountpoint -q "$mount_path"; then
                return
              fi

              longhorn_path="$mount_path/longhorn"
              mkdir -p "$longhorn_path"

              ${pkgs.jq}/bin/jq -nc \
                --arg path "$longhorn_path/" \
                --argjson storageReserved "$(storage_reserved "$mount_path" "$storage_reserved_percent")" \
                '{
                  path: $path,
                  allowScheduling: true,
                  storageReserved: $storageReserved
                }'
            }

            disk_config_entry() {
              mount_path="$1"

              if ! ${pkgs.util-linux}/bin/mountpoint -q "$mount_path"; then
                return
              fi

              tags="$(disk_tags "$mount_path")"
              if [ -z "$tags" ]; then
                return
              fi

              longhorn_path="$mount_path/longhorn"
              mkdir -p "$longhorn_path"

              ${pkgs.jq}/bin/jq -nc \
                --arg path "$longhorn_path/" \
                --argjson tags "$tags" \
                '{
                  path: $path,
                  allowScheduling: true,
                  tags: $tags
                }'
            }

            longhornDefaultDisksConfig="$(
              {
                default_disk_config_entry "/var/lib/longhorn/" "$STORAGE_RESERVED_PERCENTAGE_FOR_DEFAULT_DISK"
                for mount_path in "''${MOUNT_ROOT}"/*; do
                  if [ -d "$mount_path" ]; then
                    disk_config_entry "$mount_path"
                  fi
                done
              } | ${pkgs.jq}/bin/jq -sc '.'
            )"

          ${pkgs.kubectl}/bin/kubectl annotate node ${config.networking.hostName} \
            node.longhorn.io/default-disks-config="$longhornDefaultDisksConfig" \
            --overwrite
        '';
      };
    })
  ]);
}
