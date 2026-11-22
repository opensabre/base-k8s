# IAC on hwy

Use `docker-compose-iac-platform.yml` with `overrides/iac-platform-hwy.yml` and a protected environment file. Reuse the existing hwy IQC bridge and existing Redis/Nacos/shared services. Publish only application port 8050; management port 18090 binds to loopback by default; on hwy bind it to the private VPN address with IAC_MANAGEMENT_BIND_ADDRESS and set IAC_MANAGEMENT_HOST to the same address. Pin IAC_PLATFORM_IMAGE to a sha tag and record its digest.

Provision a separate `iac_platform` database and DML-only application account. Apply the IAC-owned Flyway baseline with a separate administrative migration identity. Follow `iac-platform/docs/deployment.md` for backups, stopping both IQC instances, verified seven-table import, authorization and gateway publication, and rollback. Keep the Jasypt key and referenced environment secrets consistent with the source.

The rollout requires explicit approval for shared configuration. This rollout was approved on 2026-11-22. Never grant the IAC application access to IQC tables.
