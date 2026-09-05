# Database migrations

OpenSabre currently supports MySQL. Every database-owning service keeps its Flyway migrations under
`src/main/resources/db/migration/<vendor>`; `base-k8s` provisions databases and
orchestrates migrations but does not own or copy application DDL/DML.

## Release contract

1. Build and pin each application image by immutable version or digest. The image contains its own
   migration runner, MySQL driver and migration resources.
   Load the matching `releases/<version>-database-targets.env`; every Job must pass its declared
   `FLYWAY_TARGET`, so an image cannot silently migrate beyond the reviewed release boundary.
2. Back up the target databases and verify the restore procedure.
3. Run the migration services before application services:

   ```bash
   docker compose -f docker-compose-migrations.yml run --rm base-authorization-migration
   docker compose -f docker-compose-migrations.yml run --rm base-organization-migration
   docker compose -f docker-compose-migrations.yml run --rm base-sysadmin-migration
   docker compose -f docker-compose-migrations.yml run --rm base-gateway-admin-migration
   docker compose -f docker-compose-migrations.yml run --rm iqc-platform-migration
   ```

4. Stop the release immediately if validation or migration fails. Do not automatically run
   `repair` or modify `flyway_schema_history`.
5. Start the application services only after every required migration exits successfully, then run
   schema/data verification and business smoke tests.

The all-in-one `docker-compose.yml` enforces this ordering for authorization, organization and
sysadmin through `service_completed_successfully` dependencies.

Kubernetes uses the five release-specific Jobs under `k8s/migrations/`. They are deliberately
independent: Kubernetes Deployments must not contain Flyway init containers and must be rolled out
only after all Jobs report `Complete`.

## Authoring rules

- Keep cumulative `B` migrations in `baseline/`, immutable released migrations in `history/`, new
  schema migrations in `ddl/`, and new data migrations in `dml/`.
- The current product schema and controlled seed data are frozen as the product baseline. A released
  baseline is immutable and must not be regenerated when later changes are added.
- Baseline files are generated state snapshots and may contain both schema and controlled initial
  data. `scripts/generate-flyway-baselines.sh` reproduces the initial baseline from immutable history;
  it is not part of the normal incremental authoring workflow.
- Add new versioned SQL under `ddl/` or `dml/`; never edit or rename a migration that has reached a
  shared environment.
- Use a unique, monotonically increasing version and a lowercase description, for example
  `ddl/V20260902_01__ddl_add_example_index.sql` or
  `dml/V20260902_02__dml_seed_example.sql`. Directory order does not control execution; versions do.
- Do not mix data-changing statements into `ddl/`, or schema-changing statements into `dml/`.
- Make forward migrations compatible with the currently deployed application. Use expand-contract
  for destructive changes.
- Keep database/user provisioning in `base-k8s/initdb`; keep tables, indexes, constraints and
  product seed data in the owning service.
- Never use `USE`, `CREATE DATABASE`, `DROP DATABASE`, or a schema-qualified OpenSabre table name
  in a migration. The JDBC URL and `FLYWAY_DATABASE` select the only allowed target.
- Update neither the legacy snapshot DDL nor deployment copies. Flyway migrations are the source of
  truth after adoption.
- Run `scripts/validate-flyway-migrations.sh` from the workspace before review.

## Validation isolation

Never validate Flyway against an existing development, staging, or production database. For every
test run:

1. Create a uniquely named empty database, for example `flyway_test_<service>_<timestamp>`.
2. Create a temporary account that has privileges only on that database. Do not use `root` or the
   shared application account.
3. Set both the JDBC URL database and `FLYWAY_DATABASE` to that exact name.
4. Run `migrate` twice: the first run must apply the latest `B` state baseline plus every newer
   versioned migration, and the second must execute zero migrations.
5. Run schema and seed-data assertions, then remove the temporary account and database through the
   approved cleanup procedure.

The migration runner rejects a missing or mismatched `FLYWAY_DATABASE`, and the repository validator
rejects database-switching, database-provisioning, and schema-qualified OpenSabre SQL. The scoped
database account remains the final containment boundary.

Runtime application users and migration users are separate. The Compose bootstrap provisions five
schema-owner accounts from `*_MIGRATION_USERNAME/PASSWORD`; each account is granted privileges on
exactly one database. Existing installations must provision equivalent scoped accounts before the
first Flyway adoption—restarting MySQL does not rerun `/docker-entrypoint-initdb.d`.

## Existing databases

Do not enable `baselineOnMigrate`. An existing 0.6/0.7 database must first be matched to a documented
schema fingerprint and upgraded to the cutover baseline. Only then may an operator explicitly
record the matching baseline version. Unknown drift, checksum mismatch or customer customization is
a stop condition requiring manual review.

The automated upgrade matrix uses immutable Git DDL snapshots and these explicit baseline markers:

| Existing release | authorization | organization | sysadmin |
| --- | --- | --- | --- |
| 0.6 | `20260723.01` | `20260721.02` | `20260720.02` |
| 0.7 | `20260808.01` | `20260810.01` | `20260729.01` |

Run `scripts/test-flyway-existing-upgrades.sh ..` before changing this matrix. A baseline marker is
permission to skip all earlier migrations, so it must never be guessed from the product version or
applied to an unrecognized customer schema.

Database rollback defaults to restore-from-backup or a new forward repair migration. Down migrations
are not assumed to be safe for production DDL.
