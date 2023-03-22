job "prometheus" {
    datacenters = ["aperature"]
    namespace = "monitoring"

    group "prometheus" {
        network {
            port "http" {
                to = 9090
            }
        }

        constraint {
            attribute = "${attr.unique.hostname}"
            value = "wheatley"
        }

        service {
            name = "prometheus"
            port = "http"
        }

        task "prometheus" {
            driver = "docker"
            config {
                image = "quay.io/prometheus/prometheus:v2.43.0"
                args = [
                    "--config.file=$${NOMAD_TASK_DIR}/prometheus.yml",
                    "--log.level=info",
                    "--storage.tsdb.retention.time=90d",
                    "--storage.tsdb.path=/prometheus",
                    "--web.console.libraries=/usr/share/prometheus/console_libraries",
                    "--web.console.templates=/usr/share/prometheus/consoles"
                ]
            }

            # TODO: Add volumes for persistent storage, configured to be
            # /prometheus on the container.

            template {
                destination = "local/prometheus.yml"
                data = <<EOF
global:
  scrape_interval: 10s
  evaluation_interval: 10s
scrape_configs:
- job_name: 'nomad_metrics'
  consul_sd_configs:
  - server: '{{ env "attr.unique.network.ip-address" }}:8500'
    services: ['nomad-client', 'nomad']
  relabel_configs:
  - source_labels: ['__meta_consul_tags']
    regex: '(.*)http(.*)'
    action: keep
  - source_labels: ['__meta_consul_node']
    target_label: 'node'
  # If nomad is available on multiple IPs, drop the ones which are not scrapable
  - source_labels: ['__address__']
    regex: '172(.*)'
    action: drop
  metrics_path: /v1/metrics
  params:
    format: ['prometheus']
- job_name: 'application_metrics'
  consul_sd_configs:
  - server: '{{ env "attr.unique.network.ip-address" }}:8500'
  relabel_configs:
  - source_labels: ['__meta_consul_service']
    regex: 'nomad|nomad-client|consul'
    action: drop
  # Drop services which do not want to be scraped.
  # Typically used when a job does not expose prometheus metrics.
  - source_labels: ['__meta_consul_tags']
    regex: '(.*)prometheus.io/scrape=false(.*)'
    action: 'drop'
  - source_labels: ['__meta_consul_node']
    target_label: 'node'
  - source_labels: ['__meta_consul_service']
    target_label: 'service'
                EOF
            }
        }
    }
}
