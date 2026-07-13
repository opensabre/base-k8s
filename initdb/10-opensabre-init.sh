#!/bin/bash
set -euo pipefail

mysql_root=(mysql -uroot -p"${MYSQL_ROOT_PASSWORD}")

run_sql() {
  local database="$1"
  local file="$2"

  if [ "${database}" = "-" ]; then
    "${mysql_root[@]}" < "${file}"
  else
    "${mysql_root[@]}" "${database}" < "${file}"
  fi
}

run_sql - /opt/opensabre/sql/base-authorization/os-base-auth-db.sql
run_sql - /opt/opensabre/sql/base-organization/os-base-org-db.sql
run_sql - /opt/opensabre/sql/base-sysadmin/os-base-sysadmin-db.sql

if [ "${MYSQL_USER:-root}" != "root" ]; then
  "${mysql_root[@]}" <<EOSQL
GRANT ALL PRIVILEGES ON os_base_auth.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON os_base_organization.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON os_base_sysadmin.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL
fi

run_sql os_base_auth /opt/opensabre/sql/base-authorization/os-base-auth-ddl.sql
run_sql os_base_organization /opt/opensabre/sql/base-organization/os-base-org-ddl.sql
run_sql os_base_sysadmin /opt/opensabre/sql/base-sysadmin/os-base-sysadmin-ddl.sql
