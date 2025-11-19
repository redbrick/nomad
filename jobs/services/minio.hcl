job "minio" {
  datacenters = ["aperture"]

  type = "service"

  group "minio" {
    count = 1

    network {
      port "api" {
      }
      port "console" {
      }
    }

    service {
      name = "minio-console"
      port = "console"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.minio-api.service=minio-api",
        "traefik.http.services.minio-api.loadbalancer.server.port=${NOMAD_PORT_api}",
        "traefik.http.routers.minio-api.rule=Host(`cdn.redbrick.dcu.ie`)",
        "traefik.http.routers.minio-api.entrypoints=web,websecure",
        "traefik.http.routers.minio-api.tls.certresolver=rb",

        "traefik.http.routers.minio-console.service=minio-console",
        "traefik.http.services.minio-console.loadbalancer.server.port=${NOMAD_PORT_console}",
        "traefik.http.routers.minio-console.rule=Host(`minio.rb.dcu.ie`)",
        "traefik.http.routers.minio-console.entrypoints=web,websecure",
        "traefik.http.routers.minio-console.tls.certresolver=rb",
      ]
    }

    task "minio" {
      driver = "docker"

      config {
        image = "quay.io/minio/minio"
        ports = ["api", "console"]

        command = "server"
        args    = ["/data", "--address", ":${NOMAD_PORT_api}", "--console-address", ":${NOMAD_PORT_console}"]

        volumes = [
          "/storage/nomad/minio:/data",
        ]
      }
      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
MINIO_ROOT_USER={{ key "minio/root/username" }}
MINIO_ROOT_PASSWORD={{ key "minio/root/password" }}
EOH
      }
      resources {
        cpu    = 1000
        memory = 800
      }
    }
  }
}
