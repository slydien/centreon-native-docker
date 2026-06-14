#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# supervisor.sh : supervises httpd + php-fpm in a single container
#
# Why not s6-overlay / supervisord ?
#   - Extra binary to package for a single process pair
#   - tini already handles PID 1 + zombie reaping ; bash + `wait -n` is enough
#   - When either process exits, the container exits => kubelet restarts it
# ---------------------------------------------------------------------------
set -euo pipefail
log() { printf '[supervisor] %s\n' "$*" >&2; }

shutdown() {
  log "received signal, stopping children"
  [[ -n "${php_pid:-}" ]] && kill -TERM "${php_pid}"  2>/dev/null || true
  [[ -n "${httpd_pid:-}" ]] && kill -TERM "${httpd_pid}" 2>/dev/null || true
  wait
  exit 0
}
trap shutdown TERM INT

log "starting php-fpm in foreground"
/usr/sbin/php-fpm --nodaemonize --fpm-config /etc/php-fpm.conf &
php_pid=$!

log "starting httpd in foreground"
/usr/sbin/httpd -D FOREGROUND &
httpd_pid=$!

log "supervising PIDs httpd=${httpd_pid} php-fpm=${php_pid}"
# wait -n : exit as soon as one of the two processes dies
wait -n "${php_pid}" "${httpd_pid}"
exit_code=$?
log "one child exited with code ${exit_code} — propagating"
shutdown
exit "${exit_code}"
