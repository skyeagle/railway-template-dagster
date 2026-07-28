# Deploy and Host Dagster with Railway

Dagster is an open-source data orchestrator for building, observing, and operating data assets and jobs. This template deploys Dagster OSS with a public webserver, private daemon, sample asset job, and persistent PostgreSQL storage.

## About Hosting Dagster

The webserver serves Dagster's UI and GraphQL API, while the private daemon evaluates schedules, dequeues runs, and executes one run at a time. PostgreSQL persists run, event-log, schedule, and concurrency state, so application restarts do not erase orchestration history.

## Why Deploy Dagster on Railway?

Railway gives the three-service topology private networking, managed public ingress, persistent database storage, health checks, and centralized deployment logs. The included example asset and schedule make the installation useful immediately without requiring users to assemble Dagster's webserver, daemon, and storage configuration themselves.

## Common Use Cases

- Evaluate Dagster's asset and job model.
- Run lightweight internal data workflows.
- Build scheduled ingestion and transformation jobs.
- Prototype Dagster integrations before moving to a larger executor topology.

## Dependencies for Dagster Hosting

- PostgreSQL stores Dagster's run, event, schedule, and concurrency state.
- The Dagster webserver exposes the UI and GraphQL API on port 3000.
- The Dagster daemon evaluates schedules and launches queued runs.

### Deployment Dependencies

No user-supplied environment variables are required. Both Dagster services build from the stable `release/v1` branch and receive Railway's private PostgreSQL connection automatically. Dagster OSS does not include user authentication, so place an access-control proxy in front of the public domain before handling sensitive metadata. The single-daemon executor is limited to one concurrent run and is intended for evaluation or small internal workloads.
