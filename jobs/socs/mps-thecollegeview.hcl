job "mps-thecollegeview" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "thecollegeview.ie"
  }

  group "tcv" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
      port "fpm" {
        to = 9000
      }
      port "db" {
        to = 3306
      }
    }

    service {
      name = "tcv-web"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.tcv.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.tcv.entrypoints=web,websecure",
        "traefik.http.routers.tcv.tls.certresolver=lets-encrypt",
      ]
    }


    task "tcv-nginx" {
      driver = "docker"
      config {
        image = "nginx:alpine"
        ports = ["http"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf",
          "/storage/nomad/mps-thecollegeview:/var/www/html/",
        ]
      }
      resources {
        cpu    = 200
        memory = 100
      }
      template {
        data        = <<EOH
# user www-data www-data;
error_log /dev/stderr error;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    server_tokens off;
    error_log /dev/stderr error;
    access_log /dev/stdout;
    charset utf-8;

    server {
      server_name {{ env "NOMAD_META_domain" }};
      listen 80;
      listen [::]:80;
      root /var/www/html;
      index index.php index.html index.htm;

      client_max_body_size 5m;
      client_body_timeout 60;

      # Pass all folders to FPM
      location / {
        try_files $uri $uri/ /index.php?$args;
      }

      # Pass REST API to FPM
      location /wp-json/ {
          try_files $uri $uri/ /index.php?$args;
      }

      # Pass the PHP scripts to FastCGI server
      location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass {{ env "NOMAD_ADDR_fpm" }};
        fastcgi_index index.php;
      }

      location ~ /\.ht {
        deny all;
      }
    }
}
EOH
        destination = "local/nginx.conf"
      }
    }

    task "tcv-phpfpm" {
      driver = "docker"

      config {
        image = "wordpress:php8.3-fpm-alpine"
        ports = ["fpm"]

        volumes = [
          "/storage/nomad/mps-thecollegeview:/var/www/html/",
        ]
      }

      resources {
        cpu    = 800
        memory = 500
      }

      template {
        data        = <<EOH
WORDPRESS_DB_HOST={{ env "NOMAD_ADDR_db" }}
WORDPRESS_DB_USER={{ key "mps/thecollegeview/db/username" }}
WORDPRESS_DB_PASSWORD={{  key "mps/thecollegeview/db/password" }}
WORDPRESS_DB_NAME={{ key "mps/thecollegeview/db/name" }}
WORDPRESS_TABLE_PREFIX=wp_2
EOH
        destination = "local/.env"
        env         = true
      }
    }

    service {
      name = "tcv-db"
      port = "db"

      check {
        name     = "mariadb_probe"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "tcv-db" {
      driver = "docker"

      config {
        image = "mariadb"
        ports = ["db"]

        volumes = [
          "/storage/nomad/mps-thecollegeview/db:/var/lib/mysql",
        ]
      }

      template {
        data = <<EOH
[mysqld]
max_connections = 100
key_buffer_size = 2G
query_cache_size = 0
innodb_buffer_pool_size = 6G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_io_capacity = 200
tmp_table_size = 5242K
max_heap_table_size = 5242K
innodb_log_buffer_size = 16M
innodb_file_per_table = 1

bind-address = 0.0.0.0
# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
EOH

        destination = "local/conf.cnf"
      }

      resources {
        cpu    = 800
        memory = 800
      }

      template {
        data = <<EOH
MYSQL_DATABASE={{ key "mps/thecollegeview/db/name" }}
MYSQL_USER={{ key "mps/thecollegeview/db/username" }}
MYSQL_PASSWORD={{ key "mps/thecollegeview/db/password" }}
MYSQL_RANDOM_ROOT_PASSWORD=yes
EOH

        destination = "local/.env"
        env         = true
      }
    }
  }
}
