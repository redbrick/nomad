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
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
        protocol = "https"
      }
    }

    task "nessus" {
      driver = "docker"

      config {
        image = "tenable/nessus:latest-ubuntu"
        ports = ["http"]

      }
      template {
        data        = <<EOF
USERNAME={{ key "nessus/username" }}
PASSWORD={{ key "nessus/password" }}
ACTIVATION_CODE={{ key "nessus/activation_code" }}
EOF
        destination = ".env"
        env         = true
      }

      resources {
        memory = 2000
      }
    }
  }
}
