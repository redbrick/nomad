job "forgejo-global-runner" {
  datacenters = ["sewer"]
  type        = "service"

  group "runner" {
    count = 3

    spread {
      attribute = "${node.unique.id}"
      weight    = 100
    }

    constraint {
      distinct_hosts = true
    }

    network {
      mode = "bridge"
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "docker-in-docker" {
      driver = "docker"

      # Start DinD before the runner and keep it running as a sidecar.
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image      = "docker:dind"
        privileged = true

        command = "dockerd"
        args = [
          "-H",
          "tcp://127.0.0.1:2375",
          "--tls=false",
        ]
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }

    task "runner" {
      driver = "docker"
      user   = "1001:1001"

      config {
        image = "data.forgejo.org/forgejo/runner:13"

        work_dir = "/data"
        command  = "forgejo-runner"
        args     = [
          "daemon",
          "--config",
          "/data/runner-config.yml",
        ]

        volumes = [
          "local/runner-config.yml:/data/runner-config.yml"
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
DOCKER_HOST = "tcp://127.0.0.1:2375"
EOH
      }

      template {
        destination = "local/runner-config.yml"
        change_mode = "restart"
        data        = <<EOH
log:
  level: info
  job_level: info

runner:
  file: .runner
  capacity: 1
  timeout: 3h
  shutdown_timeout: 3h
  insecure: false
  fetch_timeout: 30s
  fetch_interval: 2s
  report_interval: 1s

  labels:
    - "docker:docker://node:24-bookworm"
    - "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
    - "debian-trixie:docker://node:24-trixie"

cache:
  enabled: true
  port: 0
  dir: ""
  secret: ""

  host: ""
  proxy_port: 0
  actions_cache_url_override: ""

container:
  network: ""
  enable_ipv6: false
  privileged: true
  workdir_parent:
  valid_volumes: []

  docker_host: "tcp://127.0.0.1:2375"
  force_pull: false
  force_rebuild: false

host:
  workdir_parent: /tmp/forgejo-runner-act

server:
  connections:
    redbrick:
      url: https://git.redbrick.dcu.ie/
      uuid: {{ key "forgejo/global-runner/uuid" }}
      token: {{ key "forgejo/global-runner/token" }}

EOH
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}