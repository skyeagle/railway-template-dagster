# Dagster on Railway

This template deploys Dagster OSS as a public webserver, a private daemon, and a Railway PostgreSQL database. Both Dagster services build the same stable release branch, while the daemon dequeues and executes at most one run at a time without access to a host Docker socket.

[Deploy Dagster on Railway](https://railway.com/deploy/dagster)

The included `daily_order_summary` asset and `daily_metrics_job` give a new deployment a deterministic first run. Replace `app/definitions.py` with your own assets, jobs, schedules, sensors, and resources.

## Services

- **Dagster Webserver** serves the UI and GraphQL API on port 3000.
- **Dagster Daemon** evaluates schedules and sensors, dequeues runs, launches each run as a subprocess, and exposes a private readiness endpoint that checks required daemon heartbeats.
- **PostgreSQL** persists run, event-log, schedule, and concurrency state.

## Environment variables

No user-supplied variables are required. Railway creates the PostgreSQL credentials and injects its private `DATABASE_URL` into both Dagster services.

| Variable | Service | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | Webserver, daemon | Railway private PostgreSQL connection; configured automatically. |
| `DAGSTER_HOME` | Webserver, daemon | Points Dagster at the bundled instance configuration. |
| `PORT` | Webserver | Sets the public HTTP listener to port 3000. |
| `PORT` | Daemon | Sets the private heartbeat-readiness listener to port 3001. |

Add credentials needed by your own assets to the daemon service. Add them to the webserver only if loading your definitions requires them, because unnecessary duplication widens secret exposure.

## Use on Railway

Deploy the template, open the Dagster Webserver domain, and materialize `daily_order_summary` from the Assets page. The run enters PostgreSQL-backed queued storage, the daemon launches it, and its materialization metadata remains visible after a restart.

Dagster OSS does not include user authentication. The generated domain is suitable for evaluation or non-sensitive internal orchestration; put an access-control proxy in front of it before storing sensitive metadata or exposing it broadly.

The template uses `NoOpComputeLogManager`, so structured Dagster event logs are persisted in PostgreSQL but raw stdout and stderr are not shown in the UI. Configure S3, GCS, or Azure compute-log storage when raw logs must survive across services.

## Fork or publish your own version

Marketplace deployments intentionally build from this repository's stable `railway-template-v1` branch, so ordinary template users do not need to change the source.

If you fork this repository or publish a separately maintained variant, update the `github(...)` source in `.railway/railway.ts` to your own `owner/repository`, create the named release branch in that repository, and grant the Railway GitHub App access to it. Applying the IaC without those changes continues to deploy `tech-progress/railway-template-dagster`.

## Run locally

```bash
docker compose up --build --wait
./scripts/smoke.sh
docker compose down --volumes
```

`scripts/smoke.sh` checks the health endpoint and GraphQL API, submits the sample job to PostgreSQL-backed queued storage, and waits for the daemon to launch it successfully.

## Limits

The queued run coordinator is capped at one concurrent run because all run subprocesses share the daemon container's CPU and memory. Raise `max_concurrent_runs` only after sizing the daemon for the workloads it will execute.

This is a small single-daemon topology. It does not provide high availability, distributed execution, or isolated per-run containers.

See [SUPPORT.md](SUPPORT.md) for the support boundary and [UPGRADE.md](UPGRADE.md) before changing Dagster versions.
