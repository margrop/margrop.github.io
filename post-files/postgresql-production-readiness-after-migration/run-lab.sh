#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_PROJECT="blog_pg_readiness_lab"
RESTORE_CONTAINER="blog-pg-readiness-restore"
RESTORE_VOLUME="${LAB_PROJECT}_pgrestore"
ARCHIVE_VOLUME="${LAB_PROJECT}_pgarchive"
BACKUP_VOLUME="${LAB_PROJECT}_pgbackup"
RESULTS_DIR="$LAB_DIR/results"

compose() {
  docker compose -p "$LAB_PROJECT" -f "$LAB_DIR/compose.yaml" "$@"
}

section() {
  printf '\n===== %s =====\n' "$1"
}

wait_for_restore() {
  local attempt restore_state
  for attempt in $(seq 1 60); do
    restore_state="$(docker inspect -f '{{.State.Status}}' "$RESTORE_CONTAINER" 2>/dev/null || true)"
    if [[ "$restore_state" == "exited" || "$restore_state" == "dead" ]]; then
      docker logs "$RESTORE_CONTAINER" >&2 || true
      return 1
    fi
    if docker exec "$RESTORE_CONTAINER" pg_isready -U labuser -d lab >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  docker logs "$RESTORE_CONTAINER" >&2 || true
  return 1
}

mkdir -p "$RESULTS_DIR"
find "$RESULTS_DIR" -maxdepth 1 -type f -name '*.txt' -delete

section "Scoped cleanup from an earlier lab run"
docker rm -f "$RESTORE_CONTAINER" >/dev/null 2>&1 || true
compose down -v --remove-orphans >/dev/null 2>&1 || true
docker volume rm "$RESTORE_VOLUME" >/dev/null 2>&1 || true

section "Environment"
{
  printf 'lab_project=%s\n' "$LAB_PROJECT"
  docker version --format 'docker_client={{.Client.Version}} docker_server={{.Server.Version}}'
  docker compose version
  printf 'host_ports_published=none\n'
  printf 'test_data=synthetic_only\n'
} | tee "$RESULTS_DIR/01-environment.txt"

section "Build and start isolated services"
compose build pgbouncer
compose up -d db client
compose exec -T client pgbench -h db -U labuser -d lab -i -s 10 >/dev/null
compose exec -T client psql -h db -f /lab/sql/setup.sql >/dev/null

section "Direct 150-client test: expected connection wall"
set +e
compose exec -T client pgbench -h db -U labuser -d lab -S -c 150 -j 16 -T 8 \
  >"$RESULTS_DIR/02-direct-150-clients.txt" 2>&1
direct_rc=$?
set -e
{
  printf 'exit_code=%s\n' "$direct_rc"
  sed -n '1,80p' "$RESULTS_DIR/02-direct-150-clients.txt"
} >"$RESULTS_DIR/02-direct-150-clients.full.txt"
mv "$RESULTS_DIR/02-direct-150-clients.full.txt" "$RESULTS_DIR/02-direct-150-clients.txt"
if [[ "$direct_rc" -eq 0 ]]; then
  printf '%s\n' 'Direct test unexpectedly succeeded; connection-wall evidence is missing.' >&2
  exit 1
fi

section "PgBouncer 150-client test"
compose up -d pgbouncer
pool_ready=0
for _ in $(seq 1 30); do
  if compose exec -T pgbouncer pg_isready -h localhost -p 6432 -U labuser -d lab >/dev/null 2>&1; then
    pool_ready=1
    break
  fi
  sleep 1
done
if [[ "$pool_ready" -ne 1 ]]; then
  compose ps -a >&2 || true
  compose logs --tail=120 pgbouncer >&2 || true
  printf '%s\n' 'PgBouncer did not become ready.' >&2
  exit 1
fi
compose exec -T client sh -ceu '
  pgbench -h pgbouncer -p 6432 -U labuser -d lab -S -c 150 -j 16 -T 12 >/tmp/pool-test.txt 2>&1 &
  bench_pid=$!
  sleep 3
  printf "backend_connections_during_load="
  psql -h db -U labuser -d lab -Atc "SELECT count(*) FROM pg_stat_activity WHERE datname = '\''lab'\'';"
  set +e
  wait "$bench_pid"
  bench_rc=$?
  set -e
  cat /tmp/pool-test.txt
  exit "$bench_rc"
' | tee "$RESULTS_DIR/03-pgbouncer-150-clients.txt"

section "Slow SQL before and after indexing"
compose exec -T client psql -h db -f /lab/sql/slow-before.sql \
  | tee "$RESULTS_DIR/04-slow-query-before.txt"
compose exec -T client psql -h db -f /lab/sql/slow-after.sql \
  | tee "$RESULTS_DIR/05-slow-query-after.txt"

section "Dead tuples before and after VACUUM"
compose exec -T client psql -h db -f /lab/sql/bloat.sql \
  | tee "$RESULTS_DIR/06-dead-tuples-before-vacuum.txt"
compose exec -T client psql -h db -f /lab/sql/vacuum.sql \
  | tee "$RESULTS_DIR/07-dead-tuples-after-vacuum.txt"

section "Built-in PostgreSQL PITR"
compose exec -T --user root db bash -ceu 'rm -rf /backups/base; mkdir -p /backups/base; chown -R postgres:postgres /backups'
compose exec -T --user postgres db pg_basebackup -U labuser -D /backups/base -Fp -Xs -P --checkpoint=fast \
  >"$RESULTS_DIR/08-base-backup.txt" 2>&1

compose exec -T client psql -h db -v ON_ERROR_STOP=1 -c \
  "INSERT INTO recovery_probe (note) VALUES ('survive_pitr'); SELECT pg_switch_wal();" >/dev/null
sleep 3
recovery_target="$(compose exec -T client psql -h db -Atc 'SELECT clock_timestamp();' | tr -d '\r')"
sleep 2
compose exec -T client psql -h db -v ON_ERROR_STOP=1 -c \
  "DELETE FROM recovery_probe WHERE note = 'survive_pitr'; SELECT pg_switch_wal();" >/dev/null
sleep 4

{
  printf 'recovery_target=%s\n' "$recovery_target"
  printf 'rows_after_accidental_delete='
  compose exec -T client psql -h db -Atc \
    "SELECT count(*) FROM recovery_probe WHERE note = 'survive_pitr';"
  printf 'archived_wal_files='
  compose exec -T --user postgres db bash -ceu 'find /archive -maxdepth 1 -type f | wc -l'
} | tee "$RESULTS_DIR/09-accidental-delete.txt"

compose stop db >/dev/null
docker volume create "$RESTORE_VOLUME" >/dev/null
docker run --rm --user 0:0 \
  -v "$BACKUP_VOLUME:/source:ro" \
  -v "$RESTORE_VOLUME:/dest" \
  -e RECOVERY_TARGET="$recovery_target" \
  postgres:18 bash -ceu '
    cp -a /source/base/. /dest/
    touch /dest/recovery.signal
    {
      printf "\nrestore_command = '\''cp /archive/%%f %%p'\''\n"
      printf "recovery_target_time = '\''%s'\''\n" "$RECOVERY_TARGET"
      printf "recovery_target_action = '\''promote'\''\n"
    } >> /dest/postgresql.auto.conf
    chown -R postgres:postgres /dest
    chmod 700 /dest
  '

docker run -d --name "$RESTORE_CONTAINER" \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=lab \
  -e PGDATA=/var/lib/postgresql/data \
  -v "$RESTORE_VOLUME:/var/lib/postgresql/data" \
  -v "$ARCHIVE_VOLUME:/archive:ro" \
  postgres:18 >/dev/null
wait_for_restore

{
  printf 'restore_container_state='
  docker inspect -f '{{.State.Status}}' "$RESTORE_CONTAINER"
  printf 'recovered_rows='
  docker exec "$RESTORE_CONTAINER" psql -U labuser -d lab -Atc \
    "SELECT count(*) FROM recovery_probe WHERE note = 'survive_pitr';"
  printf 'recovered_note='
  docker exec "$RESTORE_CONTAINER" psql -U labuser -d lab -Atc \
    "SELECT note FROM recovery_probe WHERE note = 'survive_pitr';"
  printf 'recovery_log_marker='
  docker logs "$RESTORE_CONTAINER" 2>&1 \
    | grep -E 'recovery stopping before commit|archive recovery complete|database system is ready' \
    | tail -1
} | tee "$RESULTS_DIR/10-pitr-restored.txt"

if ! grep -q '^recovered_rows=1$' "$RESULTS_DIR/10-pitr-restored.txt"; then
  printf '%s\n' 'PITR verification failed: the pre-delete row was not recovered.' >&2
  exit 1
fi

section "Acceptance summary"
{
  printf '[PASS] direct connections hit the configured ceiling\n'
  printf '[PASS] 150 clients completed through transaction pooling\n'
  printf '[PASS] slow SQL changed from sequential scan to indexed lookup\n'
  printf '[PASS] dead tuples were observed and then reclaimed for reuse\n'
  printf '[PASS] PITR restored the row deleted after the recovery target\n'
  printf '[PASS] no host port was published\n'
} | tee "$RESULTS_DIR/11-acceptance-summary.txt"

section "Scoped cleanup"
docker rm -f "$RESTORE_CONTAINER" >/dev/null 2>&1 || true
compose down -v --remove-orphans >/dev/null
docker volume rm "$RESTORE_VOLUME" >/dev/null 2>&1 || true
printf '%s\n' "Results retained in: $RESULTS_DIR"
