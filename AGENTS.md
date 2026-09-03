# Repository Guidelines

## Project Structure & Module Organization

- `docker-compose-base-*.yml` holds service stacks for core infrastructure components (gateway, authorization, organization, sysadmin).
- `docker-compose-opensabre-admin.yml` provides the admin stack.
- `config/` contains shared configuration such as `config/bootstrap.yml` (Nacos discovery settings).
- `.env` stores environment overrides for local deployments.

## Build, Test, and Development Commands

This repo is infrastructure-oriented and uses Docker Compose. Common flows:

- `docker compose -f docker-compose-base-gateway.yml up -d`
  Starts the gateway stack in detached mode.
- `docker compose -f docker-compose-base-authorization.yml up -d`
  Starts the authorization stack.
- `docker compose -f docker-compose-opensabre-admin.yml down`
  Stops and removes the admin stack containers.

If you add new stacks, follow the `docker-compose-base-<name>.yml` naming pattern.

## Coding Style & Naming Conventions

- YAML files use 2-space indentation (match `config/bootstrap.yml`).
- Compose files follow the `docker-compose-<scope>-<name>.yml` pattern for clarity.
- Keep configuration keys aligned with upstream service docs (e.g., Nacos, Redis).

## Testing Guidelines

Database migration validation is automated:

- `scripts/validate-flyway-migrations.sh ..` checks ownership, naming, and target-containment rules.
- `scripts/validate-database-release-targets.sh .. releases/1.1.3-database-targets.env` checks the release mapping.
- `scripts/test-flyway-fresh-install.sh ..` uses a disposable MySQL container and isolated per-service accounts.

## Commit & Pull Request Guidelines

- The git history is minimal and does not indicate a strict commit format. Use short, imperative summaries (for example, “add gateway compose stack”).
- PRs should include:
  - A brief description of the stack or config change.
  - Any new environment variables added to `.env`.
  - A note on how to run the updated stack locally.

## Security & Configuration Tips

- Avoid committing secrets to `.env`. Use placeholders and document required values.
- Verify IPs and service endpoints in `config/bootstrap.yml` match the target environment.
