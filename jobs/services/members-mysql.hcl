job "members-mysql" {
  datacenters = ["aperture"]

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "wheatley"
  }

  group "db" {
    network {
      port "db" {
        static = 3306
      }
    }

    task "mariadb" {
      driver = "docker"

      template {
        data = <<EOH
MYSQL_ROOT_PASSWORD="{{ key "members-mysql/root/password" }}"
MYSQL_USER="{{ key "members-mysql/user/username" }}"
MYSQL_PASSWORD="{{ key "members-mysql/user/password" }}"
EOH

        destination = "local/file.env"
        env         = true
      }

      config {
        image = "mariadb:latest"
        ports = ["db"]

        volumes = [
          "/opt/members-mysql:/var/lib/mysql",
          "local/server.cnf:/etc/mysql/mariadb.conf.d/50-server.cnf",
        ]
      }

      template {
        data        = <<EOH
[server]

[mariadbd]

pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr

bind-address            = 0.0.0.0

expire_logs_days        = 10

character-set-server     = utf8mb4
character-set-collations = utf8mb4=uca1400_ai_ci

[mariadbd]
        EOH
        destination = "local/server.cnf"
      }

      resources {
        cpu    = 400
        memory = 800
      }

      service {
        name = "members-mysql"
        port = "db"

        check {
          type     = "tcp"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}
