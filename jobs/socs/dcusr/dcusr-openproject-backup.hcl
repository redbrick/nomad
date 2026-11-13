job "dcusr-openproject-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  meta {
    target_job   = "dcusr-openproject"
    target_group = "database"
    target_task  = "postgres"
    backup_dir   = "/storage/backups/nomad/dcusr-openproject"
    retain_days  = "3"
  }

  periodic {
    crons            = ["0 */3 * * *"]
    time_zone        = "Europe/Dublin"
    prohibit_overlap = true
  }

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

    task "postgres-backup" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["${NOMAD_TASK_DIR}/backup.sh"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/backup.env"
        env         = true
        data        = <<EOH
DB_USER={{ key "socs/dcusr/openproject/db/user" }}
DB_NAME={{ key "socs/dcusr/openproject/db/name" }}
DISCORD_WEBHOOK={{ key "socs/dcusr/postgres/webhook/discord" }}
EOH
      }

      template {
        destination = "${NOMAD_TASK_DIR}/backup.sh"
        perms       = "0755"
        data        = <<EOH
#!/bin/bash
set -euo pipefail

job_name="$${NOMAD_JOB_NAME%%/*}"
backup_dir="$${NOMAD_META_backup_dir}"
file="$${backup_dir}/postgresql-openproject-$(date +%Y-%m-%d_%H-%M-%S).dump"

fail() {
  echo "Backup FAILED: $1" >&2
  rm -f "$${file}" "$${file}.partial"
  curl -sS -H "Content-Type: application/json" -d \
    '{"content": "<@&585512338728419341> `PostgreSQL` backup for **'"$${job_name}"'** has just **FAILED**\nReason: '"$1"'\nFile name: `'"$${file}"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"$${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
    "$${DISCORD_WEBHOOK}" || true
  exit 1
}
trap 'fail "unexpected error on line $${LINENO}"' ERR

mkdir -p "$${backup_dir}"

alloc_id=$(nomad job allocs -json "$${NOMAD_META_target_job}" \
  | jq -r --arg g "$${NOMAD_META_target_group}" \
      '[.[] | select(.TaskGroup == $g and .ClientStatus == "running")][0].ID // empty')
[ -n "$${alloc_id}" ] || fail "no running $${NOMAD_META_target_group} allocation in $${NOMAD_META_target_job}"

# .partial until verified.
nomad alloc exec -task "$${NOMAD_META_target_task}" "$${alloc_id}" \
  pg_dump -U "$${DB_USER}" -d "$${DB_NAME}" -Fc > "$${file}.partial" \
  || fail "pg_dump exited non-zero"

[ -s "$${file}.partial" ] || fail "dump is empty"
mv "$${file}.partial" "$${file}"

find "$${backup_dir}" -name 'postgresql-openproject-*.dump' -mtime "+$${NOMAD_META_retain_days}" -delete

echo "Backup successful: $${file} ($(du -h "$${file}" | cut -f1))"
EOH
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  # rsync --link-dest snapshots: unchanged files are hard links.
  group "assets-backup" {
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
          "/storage/nomad/${NOMAD_META_target_job}/assets:/src:ro",
          "${NOMAD_META_backup_dir}/assets:/backup",
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
snap="/backup/$(date +%Y-%m-%d_%H-%M-%S)"

fail() {
  echo "Assets backup FAILED: $1" >&2
  rm -rf "$${snap}.partial"
  command -v curl >/dev/null && curl -sS -H "Content-Type: application/json" -d \
    '{"content": "<@&585512338728419341> `Assets` backup for **'"$${job_name}"'** has just **FAILED**\nReason: '"$1"'\nSnapshot: `'"$${NOMAD_META_backup_dir}/assets"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"$${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
    "$${DISCORD_WEBHOOK}" || true
  exit 1
}

apk add --no-cache --quiet rsync curl || fail "apk add failed"

[ -n "$(ls -A /src)" ] || fail "source assets directory is empty"

rsync -a --delete --link-dest=/backup/latest /src/ "$${snap}.partial/" || fail "rsync exited non-zero"
mv "$${snap}.partial" "$${snap}"
ln -sfn "$(basename "$${snap}")" /backup/latest

# Prune by name, not mtime (rsync -a keeps source mtime).
ls -1d /backup/20*_* 2>/dev/null | grep -v '\.partial$' | sort -r | tail -n +$((keep + 1)) | xargs -r rm -rf

echo "Assets snapshot successful: $${snap} ($(du -sh "$${snap}" | cut -f1) apparent)"
EOH
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
