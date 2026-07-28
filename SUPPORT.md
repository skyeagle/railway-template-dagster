# Support boundary

This template supports the bundled Dagster webserver and daemon, Railway PostgreSQL storage, the included example job, and upgrades between tested pinned releases.

It does not provide Dagster Plus features, authentication, high availability, distributed executors, user-code isolation, or support for arbitrary integration libraries. Problems in custom assets should first be reproduced against the included `daily_metrics_job`.

When reporting a template problem, include the Dagster version, failing service, deployment logs with secrets removed, and whether the included sample job still succeeds.
