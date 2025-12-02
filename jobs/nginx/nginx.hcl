job "nginx" {
  datacenters = ["aperture"]

  type = "service"

  group "aperture" {
    count = 3

    network {
      port "http" {
        to = "80"
      }

      port "https" {
        to = "443"
      }
    }

    service {
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx-aperture.rule=Host(`aperture.redbrick.dcu.ie`)",
        "traefik.http.routers.nginx-aperture.entrypoints=web,websecure",
        "traefik.http.routers.nginx-aperture.tls.certresolver=rb"
      ]
    }

    task "aperture" {
      driver = "docker"

      config {
        image = "nginx"
        ports = ["http", "https"]
        volumes = [
          "local/index.html:/usr/share/nginx/html/index.html",
        ]
      }

      artifact {
        source = "https://raw.githubusercontent.com/redbrick/nomad/master/jobs/nginx/index.html"
      }

      template {
        source      = "local/index.html"
        destination = "local/index.html"
      }
    }
  }

  group "glados" {
    count = 1

    network {
      port "http" {
        to = "80"
      }

      port "https" {
        to = "443"
      }
    }

    service {
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx-glados.rule=Host(`glados.redbrick.dcu.ie`)",
        "traefik.http.routers.nginx-glados.entrypoints=web,websecure",
        "traefik.http.routers.nginx-glados.tls.certresolver=rb"
      ]
    }

    task "glados" {
      constraint {
        attribute = "${attr.unique.hostname}"
        value     = "glados"
      }
      driver = "docker"

      config {
        image = "nginx"
        ports = ["http", "https"]
        volumes = [
          "local/index.html:/usr/share/nginx/html/index.html",
        ]
      }

      artifact {
        source = "https://raw.githubusercontent.com/redbrick/nomad/master/jobs/nginx/glados.html"
      }

      template {
        source      = "local/glados.html"
        destination = "local/index.html"
      }
    }
  }

  group "wheatley" {
    count = 1

    network {
      port "http" {
        to = "80"
      }

      port "https" {
        to = "443"
      }
    }

    service {
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx-wheatley.rule=Host(`wheatley.redbrick.dcu.ie`)",
        "traefik.http.routers.nginx-wheatley.entrypoints=web,websecure",
        "traefik.http.routers.nginx-wheatley.tls.certresolver=rb"
      ]
    }

    task "wheatley" {
      constraint {
        attribute = "${attr.unique.hostname}"
        value     = "wheatley"
      }

      driver = "docker"

      config {
        image = "nginx"
        ports = ["http", "https"]
        volumes = [
          "local/index.html:/usr/share/nginx/html/index.html",
        ]
      }

      artifact {
        source = "https://raw.githubusercontent.com/redbrick/nomad/master/jobs/nginx/wheatley.html"
      }

      template {
        source      = "local/wheatley.html"
        destination = "local/index.html"
      }
    }
  }

  group "chell" {
    count = 1

    network {
      port "http" {
        to = "80"
      }

      port "https" {
        to = "443"
      }
    }

    service {
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx-chell.rule=Host(`chell.redbrick.dcu.ie`)",
        "traefik.http.routers.nginx-chell.entrypoints=web,websecure",
        "traefik.http.routers.nginx-chell.tls.certresolver=rb"
      ]
    }

    task "chell" {
      constraint {
        attribute = "${attr.unique.hostname}"
        value     = "chell"
      }

      driver = "docker"

      config {
        image = "nginx"
        ports = ["http", "https"]
        volumes = [
          "local/index.html:/usr/share/nginx/html/index.html",
        ]
      }

      artifact {
        source = "https://raw.githubusercontent.com/redbrick/nomad/master/jobs/nginx/chell.html"
      }

      template {
        source      = "local/chell.html"
        destination = "local/index.html"
      }
    }
  }
}
