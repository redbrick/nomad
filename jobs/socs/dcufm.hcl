job "dcufm" {
  datacenters = ["aperture"]

  type = "service"

  group "icecast" {
    count = 1
    network {
      port "http" {
        static = 2333
      }
    }

    constraint {
      attribute = "${attr.unique.hostname}"
      value     = "wheatley"
    }

    service {
      port = "http"
      name = "icecast-stream"
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.icecast-stream.rule=Host(`dcufm.redbrick.dcu.ie`)",
        "traefik.http.routers.icecast-stream.entrypoints=web,websecure",
        "traefik.http.routers.icecast-stream.service=icecast-stream",
        "traefik.http.routers.icecast-stream.tls=true",
        "traefik.tcp.services.icecast-stream.loadbalancer.server.port=${NOMAD_PORT_http}",
        "traefik.tcp.routers.icecast-stream.service=icecast-stream",
        "traefik.tcp.routers.icecast-stream.rule=HostSNI(`dcufm.redbrick.dcu.ie`)",
        "traefik.tcp.routers.icecast-stream.entrypoints=web,websecure",
        "traefik.tcp.routers.icecast-stream.tls=true",
        "traefik.tcp.routers.icecast-stream.tls.certresolver=rb",
      ]
    }

    task "icecast2" {
      driver = "docker"
      config {
        image = "moul/icecast"
        ports = ["http"]
        volumes = [
          "local/icecast_dcufm.xml:/etc/icecast2/icecast.xml"
        ]
      }

      template {
        data = <<EOH
<icecast>
    <limits>
        <clients>500</clients>
        <sources>5</sources>
        <threadpool>5</threadpool>
        <queue-size>524288</queue-size>
        <client-timeout>30</client-timeout>
        <header-timeout>15</header-timeout>
        <source-timeout>10</source-timeout>
        <burst-on-connect>1</burst-on-connect>
        <burst-size>65535</burst-size>
    </limits>

    <authentication>
        <source-password>{{ key "dcufm/passwords/source" }}</source-password>
        <relay-password>{{ key "dcufm/passwords/relay" }}</relay-password>

        <admin-user>{{ key "dcufm/users/admin" }}</admin-user>
        <admin-password>{{ key "dcufm/passwords/admin" }}</admin-password>
    </authentication>

    <hostname>dcufm.redbrick.dcu.ie</hostname>

    <listen-socket>
        <port>{{ env "NOMAD_PORT_http" }}</port>
        <bind-address>0.0.0.0</bind-address>
    </listen-socket>

    <fileserve>1</fileserve>

    <paths>
        <basedir>/usr/share/icecast2</basedir>

        <logdir>/var/log/icecast2</logdir>
        <webroot>/usr/share/icecast2/web</webroot>
        <adminroot>/usr/share/icecast2/admin</adminroot>

        <alias source="/" dest="/status.xsl"/>
    </paths>

    <mount>
        <mount-name>/stream.mp3</mount-name>
        <fallback-mount>/fallback.mp3</fallback-mount>
        <fallback-override>1</fallback-override>
        <fallback-when-full>1</fallback-when-full>
    </mount>

    <logging>
        <accesslog>access.log</accesslog>
        <errorlog>error.log</errorlog>
        <loglevel>4</loglevel> <!-- 4 Debug, 3 Info, 2 Warn, 1 Error -->
        <logsize>10000</logsize> <!-- Max size of a logfile -->
    </logging>
</icecast>
EOH

        destination = "local/icecast_dcufm.xml"
        perms       = "755"
      }

      template {
        data        = <<EOH
ICECAST_SOURCE_PASSWORD="{{ key "dcufm/passwords/source" }}"
ICECAST_ADMIN_PASSWORD="{{ key "dcufm/passwords/admin" }}"
ICECAST_RELAY_PASSOWRD="{{ key "dcufm/passwords/relay" }}"
ICECAST_HOSTNAME="dcufm.redbrick.dcu.ie"
EOH
        destination = "local/file.env"
        env         = true
      }
    }
  }
}
