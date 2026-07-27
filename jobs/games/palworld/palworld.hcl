job "palworld-server" {
  datacenters = ["aperture"]
  type        = "service"

  constraint {
    attribute = "${meta.ingress_vip_node}"
    value     = "1"
  }

  group "palworld" {
    count = 1

    network {
      mode = "host"

      port "game" {
        static = 8211
        to     = 8211
      }
      port "query" {
        static = 27015
        to     = 27015
      }
    }

    task "routing-forward" {
      driver = "raw_exec"
      
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        command = "/bin/sh"
        args    = ["-c", <<EOF
VIP="136.206.16.50"
HOST_IP="136.206.16.4"

echo "Flushing old Palworld experiment hooks directly from host kernel..."
iptables-legacy -t nat -D POSTROUTING -p udp --sport 8211 -j SNAT --to-source "$VIP" 2>/dev/null || true
iptables-legacy -t nat -D POSTROUTING -p udp --sport 27015 -j SNAT --to-source "$VIP" 2>/dev/null || true

# Clean up previous DNAT instances if rebuilding task to prevent rule duplication
iptables-legacy -t nat -D PREROUTING -d "$VIP" -p udp --dport 8211 -j DNAT --to-destination "$HOST_IP":8211 2>/dev/null || true
iptables-legacy -t nat -D PREROUTING -d "$VIP" -p udp --dport 27015 -j DNAT --to-destination "$HOST_IP":27015 2>/dev/null || true
iptables-legacy -t nat -D OUTPUT -d "$VIP" -p udp --dport 8211 -j DNAT --to-destination "$HOST_IP":8211 2>/dev/null || true
iptables-legacy -t nat -D OUTPUT -d "$VIP" -p udp --dport 27015 -j DNAT --to-destination "$HOST_IP":27015 2>/dev/null || true

echo "Applying fresh PREROUTING and OUTPUT DNAT rules natively..."
iptables-legacy -t nat -A PREROUTING -d "$VIP" -p udp --dport 8211 -j DNAT --to-destination "$HOST_IP":8211
iptables-legacy -t nat -A PREROUTING -d "$VIP" -p udp --dport 27015 -j DNAT --to-destination "$HOST_IP":27015
iptables-legacy -t nat -A OUTPUT -d "$VIP" -p udp --dport 8211 -j DNAT --to-destination "$HOST_IP":8211
iptables-legacy -t nat -A OUTPUT -d "$VIP" -p udp --dport 27015 -j DNAT --to-destination "$HOST_IP":27015

echo "Host routing pipeline successfully optimized for DNAT."
EOF
        ]
      }

      resources {
        cpu    = 50
        memory = 16
      }
    }


    task "server" {
      driver = "docker"

      config {
        image        = "thijsvanloef/palworld-server-docker:latest"
        network_mode = "host"

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/palworld"
        ]
      }

      env {
        PORT                       = "8211"
        QUERY_PORT                 = "27015"
        PLAYERS                    = "32"
        ENABLE_PERF_THREADING_ARGS = "true"
        RCON_ENABLED               = "true"
        RCON_PORT                  = "25575"

        IS_MULTIPLAY               = "true"

        PUID = "1000"
        PGID = "1000"

        UPDATE_ON_BOOT         = "true"
        BACKUP_ENABLED         = "true"
        BACKUP_CRON_EXPRESSION = "0 */1 * * *"

        SERVER_IP                  = "136.206.16.4"
        PUBLIC_IP                  = "136.206.16.4"

        SERVER_NAME        = "Redbrick Palworld Server"
        SERVER_DESCRIPTION = "..."
        LOG_LEVEL          = "INFO"
      }

      template {
        data        = <<EOH
ADMIN_PASSWORD={{ key "games/palworld/admin_password" }}
EOH
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 4000  
        memory = 32768
      }
    }
  }
}
