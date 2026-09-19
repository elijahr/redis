#!/usr/bin/env bash
# tests/run_matrix.sh - Fast local test runner against Redis 5, 6, and 7
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Ensure Redis 5, 6, 7 containers are running on separate ports
ensure_redis() {
  local ver=$1
  local port=$2
  local name="redis-test-${ver}"

  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
      echo "Starting existing container ${name}..."
      docker start "${name}" >/dev/null
    else
      echo "Launching ${name} on port ${port}..."
      docker run -d --name "${name}" -p "${port}:6379" "redis:${ver}-alpine" >/dev/null
    fi
  fi
  until redis-cli -p "${port}" ping >/dev/null 2>&1; do
    sleep 0.2
  done
  echo "✓ Redis ${ver} ready on port ${port}"
}

echo "================================================="
echo " Setting up Redis matrix containers (5, 6, 7)... "
echo "================================================="
ensure_redis "5" "6385"
ensure_redis "6" "6386"
ensure_redis "7" "6387"

cd "${ROOT_DIR}"

run_version_test() {
  local ver=$1
  local port=$2
  echo ""
  echo "================================================="
  echo " Running test suite against Redis ${ver} (port ${port}) "
  echo "================================================="
  REDIS_PORT="${port}" REDIS_TEST_DB=15 nimble test
}

run_version_test "5" "6385"
run_version_test "6" "6386"
run_version_test "7" "6387"

# Also test against primary Redis (port 6379) if available
if redis-cli -p 6379 ping >/dev/null 2>&1; then
  run_version_test "host/primary" "6379"
fi

echo ""
echo "================================================="
echo " ✓ ALL REDIS VERSIONS PASSED LOCALLY! "
echo "================================================="
