job "dcusr-listmonk-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  meta {
    target_job  = "dcusr-listmonk"
    db_service  = "dcusr-listmonk-db"
    uploads_dir = "/storage/nomad/dcusr-listmonk/app/uploads"
    backup_dir  = "/storage/backups/nomad/dcusr-listmonk"
    retain_days = "3"
  }

  periodic {
    crons            = ["15 */3 * * *"]
    time_zone        = "Europe/Dublin"
    prohibit_overlap = true
  }

  # Dump over the network: `nomad alloc exec` truncates large output.
  group "db-backup" {
    count = 1

    # Fail fast: no retry overlapping the next run.
    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "pg-dump" {
      driver = "docker"

      config {
        image   = "postgres:17-alpine"
        command = "/bin/sh"
        args    = ["${NOMAD_TASK_DIR}/backup.sh"]

        volumes = [
          "${NOMAD_META_backup_dir}:/backup",
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/backup.env"
        env         = true
        data        = <<EOH
{{- with service (env "NOMAD_META_db_service") }}{{ with index . 0 }}
PGHOST={{ .Address }}
PGPORT={{ .Port }}
{{- end }}{{ end }}
PGUSER={{ key "socs/dcusr/listmonk/db/username" }}
PGPASSWORD={{ key "socs/dcusr/listmonk/db/password" }}
PGDATABASE={{ key "socs/dcusr/listmonk/db/name" }}
DISCORD_WEBHOOK={{ key "socs/dcusr/postgres/webhook/discord" }}
EOH
      }

      template {
        destination = "${NOMAD_TASK_DIR}/backup.sh"
        perms       = "0755"
        data        = <<EOH
#!/bin/sh
set -euo pipefail

job_name="$${NOMAD_JOB_NAME%%/*}"
file="/backup/postgresql-listmonk-$(TZ=Europe/Dublin date +%Y-%m-%d_%H-%M-%S).dump"

fail() {
  echo "Backup FAILED: $1" >&2
  rm -f "$${file}" "$${file}.partial"
  apk add --no-cache --quiet curl >/dev/null 2>&1 || true
  command -v curl >/dev/null && curl -sS -H "Content-Type: application/json" -d \
    '{"content": "<@&585512338728419341> `PostgreSQL` backup for **'"$${job_name}"'** has just **FAILED**\nReason: '"$1"'\nFile name: `'"$${NOMAD_META_backup_dir}/$(basename "$${file}")"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"$${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
    "$${DISCORD_WEBHOOK}" || true
  exit 1
}

[ -n "$${PGHOST:-}" ] || fail "no healthy $${NOMAD_META_db_service} service in Consul"

# .partial until verified.
pg_dump -Fc -f "$${file}.partial" || fail "pg_dump exited non-zero"
pg_restore --list "$${file}.partial" >/dev/null || fail "dump is not readable by pg_restore"
mv "$${file}.partial" "$${file}"

find /backup -maxdepth 1 -name 'postgresql-listmonk-*.dump' -mtime "+$${NOMAD_META_retain_days}" -delete

echo "Backup successful: $${file} ($(stat -c %s "$${file}") bytes)"
EOH
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  # rsync --link-dest snapshots: unchanged files are hard links.
  group "uploads-backup" {
    count = 1

    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "rsync-snapshot" {
      driver = "docker"

      config {
        image   = "alpine:3.22"
        command = "/bin/sh"
        args    = ["${NOMAD_TASK_DIR}/backup.sh"]

        volumes = [
          "${NOMAD_META_uploads_dir}:/src:ro",
          "${NOMAD_META_backup_dir}/uploads:/backup",
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/backup.env"
        env         = true
        data        = <<EOH
DISCORD_WEBHOOK={{ key "socs/dcusr/postgres/webhook/discord" }}
EOH
      }

      template {
        destination = "${NOMAD_TASK_DIR}/backup.sh"
        perms       = "0755"
        data        = <<EOH
#!/bin/sh
set -euo pipefail

job_name="$${NOMAD_JOB_NAME%%/*}"
keep=$(( $${NOMAD_META_retain_days} * 8 )) # 8 runs a day
snap="/backup/$(TZ=Europe/Dublin date +%Y-%m-%d_%H-%M-%S)"

fail() {
  echo "Uploads backup FAILED: $1" >&2
  rm -rf "$${snap}.partial"
  command -v curl >/dev/null && curl -sS -H "Content-Type: application/json" -d \
    '{"content": "<@&585512338728419341> `Uploads` backup for **'"$${job_name}"'** has just **FAILED**\nReason: '"$1"'\nSnapshot: `'"$${NOMAD_META_backup_dir}/uploads"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"$${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
    "$${DISCORD_WEBHOOK}" || true
  exit 1
}

apk add --no-cache --quiet rsync curl || fail "apk add failed"

rsync -a --delete --link-dest=/backup/latest /src/ "$${snap}.partial/" || fail "rsync exited non-zero"
mv "$${snap}.partial" "$${snap}"
ln -sfn "$(basename "$${snap}")" /backup/latest

# Prune by name, not mtime (rsync -a keeps source mtime).
ls -1d /backup/20*_* 2>/dev/null | grep -v '\.partial$' | sort -r | tail -n +$((keep + 1)) | xargs -r rm -rf

echo "Uploads snapshot successful: $${snap} ($(find "$${snap}" -type f | wc -l) files)"
EOH
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
