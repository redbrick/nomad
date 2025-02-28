job "prometheus" {
  datacenters = ["aperture"]
  type = "service"

  group "prometheus" {
    count = 1

    network {
      port "http" {
        to = 9090
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["http"]

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml"
        ]
      }

      template {
        destination = "local/prometheus.yml"
        data = <<EOF
global:
  scrape_interval: 10s
  evaluation_interval: 10s

scrape_configs:
- job_name: 'nomad_metrics'
  consul_sd_configs:
    - server: 'consul.service.consul:8500'
      services: ['nomad-client', 'nomad'] # This allows for Client (Workload) and Server (Orchastration) metrics
      tags: ['http']

  metrics_path: /v1/metrics
  params:
    format: ['prometheus']

- job_name: 'container-metrics'
  consul_sd_configs:
  - server: 'consul.service.consul:8500'
    tags: ['prometheus.enable=true']
  relabel_configs:
    - source_labels: ['__meta_consul_service']
      target_label: 'job'
      replacement: 'consul-service'
    - source_labels: ['__meta_consul_tags']
      regex: '.*prometheus.path=([^,]+).*'  # Extract path from tag
      target_label: '__metrics_path__'

  metrics_path: /v1/metrics
  params:
    format: ['prometheus']


EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}

