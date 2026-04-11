job "nessus" {
  datacenters = ["aperture"]
  type        = "service"

  group "web" {
    network {
      port "http" {
        to = 8834
      }
    }

    service {
      name = "nessus"
      port = "http"

      check {
        type            = "http"
        path            = "/"
        interval        = "10s"
        timeout         = "2s"
        protocol        = "https"
        tls_skip_verify = true
      }

    }

    task "nessus" {
      driver = "docker"

      config {
        image      = "tenable/nessus:latest-ubuntu"
        ports      = ["http"]
        privileged = true # NOTE: Replace this with (one of) the below once docker driver has been configured for it

        # cap_add = ["NET_ADMIN", "NET_RAW"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/users:/opt/nessus/var/nessus/users",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOF
USERNAME        = {{ key "nessus/username" }}
PASSWORD        = {{ key "nessus/password" }}
ACTIVATION_CODE = {{ key "nessus/activation_code" }}
EOF
      }

      resources {
        cpu    = 1000
        memory = 4096
      }
    }
  }
}
