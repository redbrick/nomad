job "minio" {
  datacenters = ["aperture"]

  type = "service"

  group "minio" {
    count = 1

    network {
      port "cdn" {
        static = 9000
      }
      port "http" {
        static = 9001
      }
    }

    service {
      name = "minio-web"
      port = "http"

      check {
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.minio-cdn.service=minio-cdn",
        "traefik.http.services.minio-cdn.loadbalancer.server.port=${NOMAD_PORT_cdn}",
        "traefik.http.routers.minio-cdn.rule=Host(`cdn.redbrick.dcu.ie`)",
        "traefik.http.routers.minio-cdn.entrypoints=web,websecure",
        "traefik.http.routers.minio-cdn.tls.certresolver=lets-encrypt",

        "traefik.http.routers.minio-web.service=minio-web",
        "traefik.http.services.minio-web.loadbalancer.server.port=${NOMAD_PORT_http}",
        "traefik.http.routers.minio-web.rule=Host(`minio.rb.dcu.ie`)",
        "traefik.http.routers.minio-web.entrypoints=web,websecure",
        "traefik.http.routers.minio-web.tls.certresolver=lets-encrypt",
      ]
    }

    task "minio" {
      driver = "docker"

      config {
        image = "quay.io/minio/minio"
        ports = ["cdn","http"]

        command = "server"
        args = ["/data", "--console-address", ":9001"]

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
    }
  }
}
