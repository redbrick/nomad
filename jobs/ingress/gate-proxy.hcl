job "gate-proxy" {
  datacenters = ["aperture"]
  node_pool   = "ingress"
  type        = "service"

  group "gate-proxy" {
    count = 1

    network {
      port "mc" {
        static = 25565
      }
    }

    service {
      port = "mc"

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "gate-proxy" {
      driver = "docker"

      config {
        image = "ghcr.io/minekube/gate"
        ports = ["mc"]

        volumes = [
          "local/config.yaml:/config.yaml"
        ]
      }

      template {
        data        = <<EOH
# This is a simplified config where the rest of the
# settings are omitted and will be set by default.
# See config.yml for the full configuration options.
config:
  bind: 0.0.0.0:{{ env "NOMAD_PORT_mc" }}

  forwarding:
    mode: legacy

  lite:
    enabled: true
    routes:
        # Consul template to generate routes
        # matches against all consul services ending in "-mc"
        # NOTE: each minecraft job must have both:
        # - a name ending in "-mc"
        # - a port attached to the service
        {{- range services }}
        {{- if .Name | regexMatch ".*-mc$" }}
          {{- range service .Name }}
      - host: {{ .Name }}.rb.dcu.ie
        backend: {{ .Name }}.service.consul:{{ .Port }}{{ end -}}{{ end -}}{{ end -}}
EOH
        destination = "local/config.yaml"
      }
    }
  }
}

