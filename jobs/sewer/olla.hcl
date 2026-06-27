job "olla" {
  datacenters = ["sewer"]
  type        = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    operator  = "="
    value     = "michelangelo"
  }

  group "olla" {
    count = 1

    network {
      port "http" {
        static       = 40114
        to           = 40114
        host_network = "lan"
      }
    }

    task "olla" {
      driver = "docker"

      config {
        image = "ghcr.io/thushan/olla:latest"
        ports = ["http"]

        args = [
          "-c",
          "/local/olla.yaml"
        ]
      }

      template {
        destination = "local/olla.yaml"
        change_mode = "restart"

        data = <<EOF
server:
  host: "0.0.0.0"
  port: 40114
  request_logging: false

proxy:
  engine: "olla"
  profile: "auto"
  load_balancer: "least-connections"
  connection_timeout: 45s

discovery:
  type: "static"

  model_discovery:
    enabled: true
    interval: 5m

  static:
    endpoints:
      - name: "ollama-44"
        url: "http://10.10.10.44:11434"
        type: "ollama"
        priority: 100
        check_interval: 5s
        check_timeout: 2s

      - name: "ollama-45"
        url: "http://10.10.10.45:11434"
        type: "ollama"
        priority: 100
        check_interval: 5s
        check_timeout: 2s

      - name: "ollama-46"
        url: "http://10.10.10.46:11434"
        type: "ollama"
        priority: 100
        check_interval: 5s
        check_timeout: 2s

routing:
  model_routing:
    type: "strict"
EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}