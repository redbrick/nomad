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

      resources {
        memory = 1000
      }
    }
  }
}
