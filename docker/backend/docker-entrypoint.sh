#!/bin/bash
set -e

wait_for() {
    local host="$1" port="$2" i
    for i in $(seq 1 90); do
        if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
            exec 3>&- 3<&-
            return 0
        fi
        sleep 2
    done
    echo "ERROR: timeout waiting for ${host}:${port}" >&2
    return 1
}

echo "[entrypoint] waiting for mysql..."
wait_for mysql 3306
echo "[entrypoint] waiting for redis..."
wait_for redis 6379
echo "[entrypoint] starting ruoyi-admin on port ${SERVER_PORT:-18080}"
exec java ${JVM_OPTS} -Djava.security.egd=file:/dev/./urandom -jar app.jar
