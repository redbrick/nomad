job "crowdsec-lapi" {
  datacenters = ["aperture"]
  type        = "service"

  group "crowdsec-lapi" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
      port "appsec" {
        to = 7422
      }
    }

    service {
      name = "crowdsec-lapi"
      port = "http"

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "crowdsec-appsec"
      port = "appsec"
    }

    task "crowdsec" {
      driver = "docker"

      config {
        image = "crowdsecurity/crowdsec"
        ports = ["http", "appsec"]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/var/lib/crowdsec/data:/var/lib/crowdsec/data",
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/etc/crowdsec:/etc/crowdsec",
          "local/acquis.yaml:/etc/crowdsec/acquis.yaml",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<-EOH
        TZ="Europe/Dublin"
        COLLECTIONS="crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-crs-inband crowdsecurity/appsec-generic-rules"
        EOH
      }

      template {
        destination = "local/acquis.yaml"
        data        = <<-EOH
        listen_addr: 0.0.0.0:7422
        path: /
        source: appsec
        appsec_configs:
          - crowdsecurity/appsec-default
          - crowdsecurity/crs-inband
        labels:
          type: appsec
        EOH
      }
    }
  }
}
