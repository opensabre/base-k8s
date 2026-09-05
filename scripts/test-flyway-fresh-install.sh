#!/usr/bin/env bash
set -euo pipefail

workspace_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
mysql_image="${MYSQL_TEST_IMAGE:-mysql:8.0}"
flyway_image="${FLYWAY_TEST_IMAGE:-redgate/flyway:11.18.0}"
run_id="$(date +%Y%m%d%H%M%S)-$$"
network="flyway-test-${run_id}"
mysql_container="flyway-test-mysql-${run_id}"
root_password="root_${run_id//-/_}_${RANDOM}"

services=(base-authorization base-organization base-sysadmin base-gateway-admin iqc-platform)
databases=(os_base_auth os_base_organization os_base_sysadmin os_base_gateway_admin iqc_platform)
expected_table_counts=(4 14 14 11 20)
seed_assertions=(
  'SELECT COUNT(*) FROM oauth2_registered_client'
  'SELECT COUNT(*) FROM base_org_user'
  'SELECT COUNT(*) FROM base_sys_dict_type'
  'SELECT 1'
  'SELECT 1'
)

requested_service="${2:-}"
if [[ -n "${requested_service}" ]]; then
  case "${requested_service}" in
    base-authorization)
      services=(base-authorization); databases=(os_base_auth); expected_table_counts=(4)
      seed_assertions=('SELECT COUNT(*) FROM oauth2_registered_client') ;;
    base-organization)
      services=(base-organization); databases=(os_base_organization); expected_table_counts=(14)
      seed_assertions=('SELECT COUNT(*) FROM base_org_user') ;;
    base-sysadmin)
      services=(base-sysadmin); databases=(os_base_sysadmin); expected_table_counts=(14)
      seed_assertions=('SELECT COUNT(*) FROM base_sys_dict_type') ;;
    base-gateway-admin)
      services=(base-gateway-admin); databases=(os_base_gateway_admin); expected_table_counts=(11)
      seed_assertions=('SELECT 1') ;;
    iqc-platform)
      services=(iqc-platform); databases=(iqc_platform); expected_table_counts=(20)
      seed_assertions=('SELECT 1') ;;
    *) echo "ERROR: unsupported service ${requested_service}" >&2; exit 2 ;;
  esac
fi

cleanup() {
  status=$?
  if [[ ${status} -ne 0 ]]; then
    docker logs "${mysql_container}" >&2 2>/dev/null || true
  fi
  docker rm -f "${mysql_container}" >/dev/null 2>&1 || true
  docker network rm "${network}" >/dev/null 2>&1 || true
  return "${status}"
}
trap cleanup EXIT INT TERM

"${workspace_root}/base-k8s/scripts/validate-flyway-migrations.sh" "${workspace_root}" "${services[@]}"

docker network create "${network}" >/dev/null
docker run -d --name "${mysql_container}" --network "${network}" \
  --memory 768m --memory-swap 1g \
  -e MYSQL_ROOT_PASSWORD="${root_password}" \
  -e MYSQL_ROOT_HOST=% \
  "${mysql_image}" \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci >/dev/null

ready=0
for _ in $(seq 1 60); do
  if docker exec "${mysql_container}" sh -c \
    'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -Nse "SELECT 1"' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [[ ${ready} -ne 1 ]]; then
  docker logs "${mysql_container}" >&2
  echo "ERROR: isolated MySQL did not become ready" >&2
  exit 1
fi

for index in "${!services[@]}"; do
  service="${services[$index]}"
  database="flyway_test_${databases[$index]}_${run_id//-/_}"
  user="flyway_${index}_${RANDOM}"
  password="migration_${run_id//-/_}_${index}_${RANDOM}"
  migration_dir="${workspace_root}/${service}/src/main/resources/db/migration/mysql"

  printf '%s\n' \
    "CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
    "CREATE USER '${user}'@'%' IDENTIFIED BY '${password}';" \
    "GRANT ALL PRIVILEGES ON \`${database}\`.* TO '${user}'@'%';" \
    | docker exec -i "${mysql_container}" sh -c \
      'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4'

  flyway=(docker run --rm --network "${network}"
    -v "${migration_dir}:/flyway/sql:ro"
    "${flyway_image}"
    "-url=jdbc:mysql://${mysql_container}:3306/${database}?useSSL=false&allowPublicKeyRetrieval=true"
    "-user=${user}"
    "-password=${password}"
    -connectRetries=60
    -validateMigrationNaming=true
    -baselineOnMigrate=false
    -cleanDisabled=true)

  "${flyway[@]}" migrate
  first_count="$(docker exec "${mysql_container}" mysql -u"${user}" -p"${password}" -Nse \
    "SELECT COUNT(*) FROM \`${database}\`.flyway_schema_history")"
  baseline_count="$(docker exec "${mysql_container}" mysql -u"${user}" -p"${password}" -Nse \
    "SELECT COUNT(*) FROM \`${database}\`.flyway_schema_history WHERE script LIKE 'B%__baseline.sql' AND success=1")"
  "${flyway[@]}" validate
  "${flyway[@]}" migrate
  second_count="$(docker exec "${mysql_container}" mysql -u"${user}" -p"${password}" -Nse \
    "SELECT COUNT(*) FROM \`${database}\`.flyway_schema_history")"
  table_count="$(docker exec "${mysql_container}" mysql -u"${user}" -p"${password}" -Nse \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${database}'")"
  seed_count="$(docker exec "${mysql_container}" mysql -u"${user}" -p"${password}" -D"${database}" -Nse \
    "${seed_assertions[$index]}")"

  if [[ "${first_count}" -eq 0 || "${first_count}" -ne "${second_count}" ]]; then
    echo "ERROR ${service}: repeat migration changed history (${first_count} -> ${second_count})" >&2
    exit 1
  fi
  if [[ -d "${migration_dir}/baseline" && "${baseline_count}" -ne 1 ]]; then
    echo "ERROR ${service}: fresh database did not apply exactly one baseline migration" >&2
    exit 1
  fi
  if [[ "${table_count}" -ne "${expected_table_counts[$index]}" || "${seed_count}" -lt 1 ]]; then
    echo "ERROR ${service}: schema/seed assertion failed (tables=${table_count}, seed=${seed_count})" >&2
    exit 1
  fi
  echo "PASS ${service}: ${first_count} migrations, ${table_count} tables, seed assertion, repeat run unchanged"
done

echo "Fresh-install Flyway validation passed for ${#services[@]} services in isolated databases."
