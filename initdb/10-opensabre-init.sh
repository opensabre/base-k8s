#!/bin/bash
set -euo pipefail

mysql_root=(mysql -uroot -p"${MYSQL_ROOT_PASSWORD}")

accounts=(
  AUTH_MIGRATION
  ORGANIZATION_MIGRATION
  SYSADMIN_MIGRATION
  GATEWAY_ADMIN_MIGRATION
  IQC_MIGRATION
)
for account in "${accounts[@]}"; do
  username_variable="${account}_USERNAME"
  password_variable="${account}_PASSWORD"
  username="${!username_variable:?${username_variable} is required}"
  password="${!password_variable:?${password_variable} is required}"
  [[ "${username}" =~ ^[a-zA-Z0-9_]{1,32}$ ]] || {
    echo "Invalid MySQL migration username in ${username_variable}" >&2
    exit 1
  }
  [[ "${password}" != *[\\\'\"$'\n'$'\r']* ]] || {
    echo "Migration passwords must not contain quotes, backslashes, or newlines" >&2
    exit 1
  }
done

# Infrastructure owns database and account provisioning. Each application image owns its schema
# and data migrations, which are applied later by a dedicated Flyway process.
"${mysql_root[@]}" <<EOSQL
CREATE DATABASE IF NOT EXISTS os_base_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS os_base_organization CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS os_base_sysadmin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS os_base_gateway_admin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS iqc_platform CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${AUTH_MIGRATION_USERNAME}'@'%' IDENTIFIED BY '${AUTH_MIGRATION_PASSWORD}';
CREATE USER IF NOT EXISTS '${ORGANIZATION_MIGRATION_USERNAME}'@'%' IDENTIFIED BY '${ORGANIZATION_MIGRATION_PASSWORD}';
CREATE USER IF NOT EXISTS '${SYSADMIN_MIGRATION_USERNAME}'@'%' IDENTIFIED BY '${SYSADMIN_MIGRATION_PASSWORD}';
CREATE USER IF NOT EXISTS '${GATEWAY_ADMIN_MIGRATION_USERNAME}'@'%' IDENTIFIED BY '${GATEWAY_ADMIN_MIGRATION_PASSWORD}';
CREATE USER IF NOT EXISTS '${IQC_MIGRATION_USERNAME}'@'%' IDENTIFIED BY '${IQC_MIGRATION_PASSWORD}';
GRANT ALL PRIVILEGES ON os_base_auth.* TO '${AUTH_MIGRATION_USERNAME}'@'%';
GRANT ALL PRIVILEGES ON os_base_organization.* TO '${ORGANIZATION_MIGRATION_USERNAME}'@'%';
GRANT ALL PRIVILEGES ON os_base_sysadmin.* TO '${SYSADMIN_MIGRATION_USERNAME}'@'%';
GRANT ALL PRIVILEGES ON os_base_gateway_admin.* TO '${GATEWAY_ADMIN_MIGRATION_USERNAME}'@'%';
GRANT ALL PRIVILEGES ON iqc_platform.* TO '${IQC_MIGRATION_USERNAME}'@'%';
FLUSH PRIVILEGES;
EOSQL

if [ "${MYSQL_USER:-root}" != "root" ]; then
  "${mysql_root[@]}" <<EOSQL
GRANT ALL PRIVILEGES ON os_base_auth.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON os_base_organization.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON os_base_sysadmin.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON os_base_gateway_admin.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON iqc_platform.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL
fi

# Optional IAC extraction: this runtime identity cannot access IQC or change table structure.
# Apply IAC-owned Flyway migrations separately using an administrative migration identity.
if [[ -n "${IAC_DATASOURCE_USERNAME:-}" || -n "${IAC_DATASOURCE_PASSWORD:-}" ]]; then
  iac_username="${IAC_DATASOURCE_USERNAME:?IAC_DATASOURCE_USERNAME is required}"
  iac_password="${IAC_DATASOURCE_PASSWORD:?IAC_DATASOURCE_PASSWORD is required}"
  [[ "$iac_username" =~ ^[a-zA-Z0-9_]{1,32}$ ]] || { echo "Invalid IAC username" >&2; exit 1; }
  [[ "$iac_username" != root ]] || { echo "IAC requires a dedicated account" >&2; exit 1; }
  [[ "$iac_password" != *[\\\'\"$'\n'$'\r']* ]] || { echo "Invalid IAC password characters" >&2; exit 1; }
  "${mysql_root[@]}" <<EOSQL
CREATE DATABASE IF NOT EXISTS iac_platform CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${iac_username}'@'%' IDENTIFIED BY '${iac_password}';
GRANT SELECT, INSERT, UPDATE, DELETE ON iac_platform.* TO '${iac_username}'@'%';
EOSQL
fi
