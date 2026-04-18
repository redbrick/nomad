job "prometheus" {
  datacenters = ["aperture"]
  type        = "service"

  group "prometheus" {
    count = 1

    network {
      port "http" {
        to = 9090
      }
    }

    task "prometheus" {
      driver = "docker"

      service {
        name = "prometheus"
        port = "http"
      }

      config {
        image = "prom/prometheus:latest"
        ports = ["http"]

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
          "local/tokens/:/etc/prometheus/tokens/"
        ]
      }

      template {
        destination = "local/prometheus.yml"
        data        = <<EOF
global:
  scrape_interval: 10s
  evaluation_interval: 10s

scrape_configs:
  - job_name: 'nomad_metrics'
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
        services: ['nomad-client', 'nomad']
        tags: ['http']
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'container-metrics'
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
        tags: ['prometheus.enable=true']
    metrics_path: /metrics
    relabel_configs:
      - source_labels: ['__meta_consul_service']
        target_label: 'job'
        replacement: 'consul-service'

      - source_labels: ['__meta_consul_tags']
        regex: '.*prometheus.path=([^,]+).*'
        target_label: '__metrics_path__'
        replacement: '/$1'

      - source_labels: ['__meta_consul_tags']
        regex: '.*prometheus.auth.bearer_token=([^,]+).*'
        target_label: '__param_bearer_token_file'
        replacement: '$1'

  - job_name: 'node-exporter'
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
        services: ['node-exporter']
    metrics_path: /metrics
    relabel_configs:
      - source_labels: ['__meta_consul_service']
        target_label: 'job'
        replacement: 'node-exporter'
EOF
      }

      template {
        destination = "local/tokens/minio"
        data        = <<EOF
{{ key "prometheus/minio" }}
EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
