# Kubernetes database migration jobs

`opensabre-1.1.3-jobs.yaml` contains five independent, rerunnable Jobs. Apply the application
Deployments only after all Jobs have completed successfully.

Before applying the file, create one Secret per database in namespace `opensabre`. Each Secret must
contain `url`, `username`, and `password`; the account must have privileges only on the database in
its URL. Expected Secret names are shown in the manifest. Never use the MySQL root or shared
application account.

Use a release-specific Job name for every release. Delete completed old Jobs only after retaining
their logs and the matching `releases/*-database-targets.env` as release evidence.
