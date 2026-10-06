job "wazuh" {
  datacenters = ["aperture"]
  type        = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "glados"
  }

  group "wazuh" {
    count = 1

    network {
      mode = "host"

      port "agent" {
        static = 1514
      }
      port "enrollment" {
        static = 1515
      }
      port "syslog" {
        static = 514
      }
      port "api" {
        static = 55000
      }
      port "indexer" {
        static = 9200
      }
      port "dashboard" {
        static = 5601
        to     = 5601
      }
    }

    # The Wazuh images use these names in their certificates and config.
    # Host networking lets the three tasks share the compose port layout.
    task "certificates" {
      driver = "docker"

      env {
        CERT_TOOL_VERSION = "4.14"
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      template {
        destination = "local/certs.yml"
        data        = file("config/certs.yml")
      }

      config {
        image = "wazuh/wazuh-certs-generator:0.0.4"

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/certs:/certificates",
          "local/certs.yml:/config/certs.yml:ro",
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "manager" {
      driver = "docker"

      template {
        destination = "local/wazuh_manager.conf"
        data        = file("config/wazuh_cluster/wazuh_manager.conf")
      }

      config {
        image        = "wazuh/wazuh-manager:4.14.7"
        hostname     = "wazuh.manager"
        network_mode = "host"
        ports        = ["agent", "enrollment", "syslog", "api"]
        extra_hosts  = ["wazuh.indexer:127.0.0.1", "wazuh.manager:127.0.0.1", "wazuh.dashboard:127.0.0.1"]
        ulimit {
            memlock = "-1"
            nofile  = "655360"
        }

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/api-configuration:/var/ossec/api/configuration",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/etc:/var/ossec/etc",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/logs:/var/ossec/logs",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/queue:/var/ossec/queue",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/multigroups:/var/ossec/var/multigroups",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/integrations:/var/ossec/integrations",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/active-response:/var/ossec/active-response/bin",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/agentless:/var/ossec/agentless",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/wodles:/var/ossec/wodles",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/filebeat-etc:/etc/filebeat",
          "/storage/nomad/${NOMAD_JOB_NAME}/manager/filebeat-var:/var/lib/filebeat",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/root-ca-manager.pem:/etc/ssl/root-ca.pem:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/wazuh.manager.pem:/etc/ssl/filebeat.pem:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/wazuh.manager-key.pem:/etc/ssl/filebeat.key:ro",
          "local/wazuh_manager.conf:/wazuh-config-mount/etc/ossec.conf:ro",
        ]
      }

      template {
        destination = "secrets/manager.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
INDEXER_URL=https://wazuh.indexer:9200
INDEXER_USERNAME=admin
INDEXER_PASSWORD={{ key "wazuh/indexer/password" }}
FILEBEAT_SSL_VERIFICATION_MODE=full
SSL_CERTIFICATE_AUTHORITIES=/etc/ssl/root-ca.pem
SSL_CERTIFICATE=/etc/ssl/filebeat.pem
SSL_KEY=/etc/ssl/filebeat.key
API_USERNAME=wazuh-wui
API_PASSWORD={{ key "wazuh/api/password" }}
EOH
      }

      service {
        name = "wazuh-manager-api"
        port = "api"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 2000
        memory = 4096
      }
    }

    task "indexer" {
      driver = "docker"

      template {
        destination = "local/wazuh.indexer.yml"
        data        = file("config/wazuh_indexer/wazuh.indexer.yml")
      }
      template {
        destination = "local/internal_users.yml"
        data        = file("config/wazuh_indexer/internal_users.yml")
      }

      config {
        image        = "wazuh/wazuh-indexer:4.14.7"
        hostname     = "wazuh.indexer"
        network_mode = "host"
        ports        = ["indexer"]
        extra_hosts  = ["wazuh.indexer:127.0.0.1", "wazuh.manager:127.0.0.1", "wazuh.dashboard:127.0.0.1"]
        ulimit {
            memlock = "-1"
            nofile  = "655360"
        }

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/indexer:/var/lib/wazuh-indexer",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/root-ca.pem:/usr/share/wazuh-indexer/config/certs/root-ca.pem:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/wazuh.indexer-key.pem:/usr/share/wazuh-indexer/config/certs/wazuh.indexer.key:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/wazuh.indexer.pem:/usr/share/wazuh-indexer/config/certs/wazuh.indexer.pem:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/admin.pem:/usr/share/wazuh-indexer/config/certs/admin.pem:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/admin-key.pem:/usr/share/wazuh-indexer/config/certs/admin-key.pem:ro",
          "local/wazuh.indexer.yml:/usr/share/wazuh-indexer/config/opensearch.yml:ro",
          "local/internal_users.yml:/usr/share/wazuh-indexer/config/opensearch-security/internal_users.yml:ro",
        ]
      }

      template {
        destination = "secrets/indexer.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
EOH
      }

      service {
        name = "wazuh-indexer"
        port = "indexer"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 2000
        memory = 4096
      }
    }

    task "dashboard" {
      driver = "docker"

      template {
        destination = "local/opensearch_dashboards.yml"
        data        = file("config/wazuh_dashboard/opensearch_dashboards.yml")
      }
      config {
        image        = "wazuh/wazuh-dashboard:4.14.7"
        hostname     = "wazuh.dashboard"
        network_mode = "host"
        ports        = ["dashboard"]
        extra_hosts  = ["wazuh.indexer:127.0.0.1", "wazuh.manager:127.0.0.1", "wazuh.dashboard:127.0.0.1"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/wazuh.dashboard.pem:/usr/share/wazuh-dashboard/certs/wazuh-dashboard.pem:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/wazuh.dashboard-key.pem:/usr/share/wazuh-dashboard/certs/wazuh-dashboard-key.pem:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs/root-ca.pem:/usr/share/wazuh-dashboard/certs/root-ca.pem:ro",
          "local/opensearch_dashboards.yml:/usr/share/wazuh-dashboard/config/opensearch_dashboards.yml:ro",
          "local/wazuh.yml:/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/dashboard/config:/usr/share/wazuh-dashboard/data/wazuh/config",
          "/storage/nomad/${NOMAD_JOB_NAME}/dashboard/custom:/usr/share/wazuh-dashboard/plugins/wazuh/public/assets/custom",
        ]
      }

      template {
        destination = "local/wazuh.yml"
        change_mode = "restart"
        data        = <<EOH
hosts:
  - 1513629884013:
      url: "https://wazuh.manager"
      port: 55000
      username: wazuh-wui
      password: "{{ key "wazuh/api/password" }}"
      run_as: true
EOH
      }

      template {
        destination = "secrets/dashboard.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
INDEXER_USERNAME=admin
INDEXER_PASSWORD={{ key "wazuh/indexer/password" }}
WAZUH_API_URL=https://wazuh.manager
DASHBOARD_USERNAME=kibanaserver
DASHBOARD_PASSWORD={{ key "wazuh/dashboard/password" }}
API_USERNAME=wazuh-wui
API_PASSWORD={{ key "wazuh/api/password" }}
EOH
      }

      service {
        name = "wazuh-dashboard"
        port = "dashboard"

        check {
          type     = "http"
          path     = "/api/status"
          interval = "10s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}