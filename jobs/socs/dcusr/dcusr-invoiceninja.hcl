job "dcusr-invoiceninja" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "invoices.solarracing.ie"
  }

  group "ninja" {
    count = 1

    network {
      port "web" { 
        to = 80 
      }
      port "fpm" { 
        to = 9000 
      }
      port "db" { 
        to = 3306 
      }
      port "redis" { 
        to = 6379 
      }
    }

    restart {
      attempts = 20
      delay    = "10s"
      interval = "10m"
      mode     = "delay"
    }

    service {
      name = "invoiceninja"
      port = "web"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_web}",
        "traefik.http.routers.dcusr-invoiceninja.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-invoiceninja.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-invoiceninja.tls=true",
        "traefik.http.routers.dcusr-invoiceninja.tls.certresolver=lets-encrypt",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image  = "invoiceninja/invoiceninja-debian:latest"
        ports  = ["fpm"]

        volumes = [
          "local/.env:/var/www/html/.env",
          "/storage/nomad/${NOMAD_JOB_NAME}/public:/var/www/html/public",
          "/storage/nomad/${NOMAD_JOB_NAME}/storage:/var/www/html/storage",
          "local/99-mysql-client-no-tls.cnf:/etc/mysql/conf.d/99-mysql-client-no-tls.cnf:ro",

        ]
      }

      resources {
        cpu    = 4000
        memory = 8192
      }

      template {
        destination = "local/.env"
        env         = true
        data = <<EOH
IS_DOCKER=true
NINJA_ENVIRONMENT=selfhost
APP_NAME="DCU Solar Racing invoicing"
APP_ENV=production
APP_DEBUG=true
APP_URL=https://{{ env "NOMAD_META_domain" }}
REQUIRE_HTTPS=true
TRUSTED_PROXIES=*
APP_KEY={{ key "dcusr/invoice/app/key" }}
PHANTOMJS_PDF_GENERATION=false

FILESYSTEM_DISK=debian_docker

# pdf
PDF_GENERATOR=snappdf

# database (like compose)
DB_CONNECTION=mysql
DB_HOST={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_DATABASE={{ key "dcusr/invoice/db/name" }}
DB_USERNAME={{ key "dcusr/invoice/db/user" }}
DB_PASSWORD={{ key "dcusr/invoice/db/password" }}
DB_STRICT=false

REDIS_HOST={{ env "NOMAD_IP_redis" }}
REDIS_PORT={{ env "NOMAD_HOST_PORT_redis" }}
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

INTERNAL_QUEUE_ENABLED=true

MAIL_MAILER=smtp
MAIL_HOST={{ key "dcusr/invoice/smtp/host" }}
MAIL_PORT={{ key "dcusr/invoice/smtp/port" }}
MAIL_USERNAME={{ key "dcusr/invoice/smtp/username" }}
MAIL_PASSWORD="{{ key "dcusr/invoice/smtp/password" }}"
MAIL_ENCRYPTION={{ key "dcusr/invoice/smtp/encryption" }}
MAIL_FROM_ADDRESS={{ key "dcusr/invoice/smtp/from_address" }}
MAIL_FROM_NAME="{{ key "dcusr/invoice/smtp/from_name" }}"
EOH
      }

       template {
        destination = "local/99-mysql-client-no-tls.cnf"
        data = <<EOH
[client]
loose-skip-ssl
loose-ssl-verify-server-cert=OFF
loose-ssl-mode=DISABLED

[mysql]
loose-skip-ssl
loose-ssl-verify-server-cert=OFF
loose-ssl-mode=DISABLED
EOH
  }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["web"]
        volumes = [
          "local/nginx:/etc/nginx/conf.d:ro",
          "/storage/nomad/${NOMAD_JOB_NAME}/public:/var/www/html/public",
          "/storage/nomad/${NOMAD_JOB_NAME}/storage:/var/www/html/storage",
      ]
    }

      template {
        destination = "local/nginx/invoiceninja.conf"
        data = <<EOH
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php index.html;
    client_max_body_size 100M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php(?:$|/) {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_index index.php;
        fastcgi_read_timeout 300;
        fastcgi_pass {{ env "NOMAD_ADDR_fpm" }};
    }

    location ~* \.(jpg|jpeg|gif|png|css|js|ico|svg|woff|woff2|ttf)$ {
        expires max;
        log_not_found off;
    }
}
EOH
    }
  }

    task "mysql" {
      driver = "docker"

      config {
        image = "mysql:8"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/mysql:/var/lib/mysql",
          "local/zz-no-tls.cnf:/etc/mysql/conf.d/zz-no-tls.cnf:ro",
      ]
    }

    resources {
      cpu    = 500
      memory = 1024
    }

    template {
      destination = "local/mysql.env"
      env         = true
      data = <<EOH
MYSQL_DATABASE={{ key "dcusr/invoice/db/name" }}
MYSQL_USER={{ key "dcusr/invoice/db/user" }}
MYSQL_PASSWORD={{ key "dcusr/invoice/db/password" }}
MYSQL_ROOT_PASSWORD={{ key "dcusr/invoice/db/root_password" }}
EOH
  }

    template {
      destination = "local/zz-no-tls.cnf"
      data = <<EOH
[mysqld]
require_secure_transport=OFF
tls_version=
admin_tls_version=
EOH
  }
}


    task "redis" {
      driver = "docker"

      config {
        image = "redis:alpine"
        ports = ["redis"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/redis:/data",
        ]
      }

      resources {
        cpu    = 150
        memory = 128
      }
    }
  }
}

