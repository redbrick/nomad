job "style-thelook" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "thelookonline.dcu.ie"
  }

  group "thelook" {
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
      port "redis" {
        to = 6379
      }
    }

    service {
      name = "thelook-web"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.thelook.rule=Host(`${NOMAD_META_domain}`) || Host(`style.redbrick.dcu.ie`)",
        "traefik.http.routers.thelook.entrypoints=web,websecure",
        "traefik.http.routers.thelook.tls.certresolver=lets-encrypt",
      ]
    }


    task "thelook-nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf",
          "/storage/nomad/style-thelook:/var/www/html/",
        ]
        group_add = [82] # www-data in alpine
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

      # NOTE: Not used here, WP super cache rule used instead
      # Pass all folders to FPM
      # location / {
      #   try_files $uri $uri/ /index.php?$args;
      # }

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

      # WP Super Cache rules.

      set $cache_uri $request_uri;

      # POST requests and urls with a query string should always go to PHP
      if ($request_method = POST) {
          set $cache_uri 'null cache';
      }

      if ($query_string != "") {
          set $cache_uri 'null cache';
      }

      # Don't cache uris containing the following segments
      if ($request_uri ~* "(/wp-admin/|/xmlrpc.php|/wp-(app|cron|login|register|mail).php|wp-.*.php|/feed/|index.php|wp-comments-popup.php|wp-links-opml.php|wp-locations.php|sitemap(_index)?.xml|[a-z0-9_-]+-sitemap([0-9]+)?.xml)") {
          set $cache_uri 'null cache';
      }

      # Don't use the cache for logged in users or recent commenters
      if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_logged_in") {
          set $cache_uri 'null cache';
      }

      # Use cached or actual file if they exists, otherwise pass request to WordPress
      location / {
          try_files /wp-content/cache/supercache/$http_host/$cache_uri/index.html $uri $uri/ /index.php?$args ;
      }
    }
}
EOH
        destination = "local/nginx.conf"
      }
    }

    task "thelook-phpfpm" {
      driver = "docker"

      config {
        image = "wordpress:php8.3-fpm-alpine"
        ports = ["fpm"]

        volumes = [
          "/storage/nomad/style-thelook:/var/www/html/",
          "local/custom.ini:/usr/local/etc/php/conf.d/custom.ini",
        ]
      }

      resources {
        cpu    = 800
        memory = 500
      }

      template {
        data        = <<EOH
WORDPRESS_DB_HOST={{ env "NOMAD_ADDR_db" }}
WORDPRESS_DB_USER={{ key "style/thelook/db/username" }}
WORDPRESS_DB_PASSWORD={{  key "style/thelook/db/password" }}
WORDPRESS_DB_NAME={{ key "style/thelook/db/name" }}
WORDPRESS_TABLE_PREFIX=wp_
WORDPRESS_CONFIG_EXTRA="define('WP_REDIS_HOST', '{{ env "NOMAD_ADDR_redis" }}');"
EOH
        destination = "local/.env"
        env         = true
      }

      template {
        data        = <<EOH
pm.max_children = 10
upload_max_filesize = 64M
post_max_size = 64M
expose_php = off
open_basedir = /var/www/html:/tmp
EOH
        destination = "local/custom.ini"
      }
    }

    service {
      name = "thelook-db"
      port = "db"
    }

    task "thelook-db" {
      driver = "docker"

      config {
        image = "mariadb"
        ports = ["db"]

        volumes = [
          "/storage/nomad/style-thelook/db:/var/lib/mysql",
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
MYSQL_DATABASE={{ key "style/thelook/db/name" }}
MYSQL_USER={{ key "style/thelook/db/username" }}
MYSQL_PASSWORD={{ key "style/thelook/db/password" }}
MYSQL_RANDOM_ROOT_PASSWORD=yes
EOH

        destination = "local/.env"
        env         = true
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["redis"]
      }

      resources {
        cpu = 200
      }
    }
  }
}
