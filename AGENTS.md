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

No automated tests are present in this repository. If you introduce tests or validation scripts, document them here and add a one-line run command (for example, `make test` or `docker compose config`).

## Commit & Pull Request Guidelines

- The git history is minimal and does not indicate a strict commit format. Use short, imperative summaries (for example, “add gateway compose stack”).
- PRs should include:
  - A brief description of the stack or config change.
  - Any new environment variables added to `.env`.
  - A note on how to run the updated stack locally.

## Security & Configuration Tips

- Avoid committing secrets to `.env`. Use placeholders and document required values.
- Verify IPs and service endpoints in `config/bootstrap.yml` match the target environment.
