# Upgrading Dagster

Dagster core, `dagster-webserver`, and integration packages use coupled version lines. Update `dagster` and `dagster-webserver` to the same release and `dagster-postgres` to its matching library release, then rebuild both application services from one commit.

Before deploying an upgrade:

1. Back up the Railway PostgreSQL volume.
2. Build the image and run `python -m unittest discover -s tests`.
3. Start the full Compose topology and run `scripts/smoke.sh`.
4. Deploy both services. Their startup wrapper runs `dagster instance migrate` before accepting work.
5. Verify the webserver, daemon heartbeat, and a fresh sample-job run before removing the database backup.

Do not downgrade after a schema migration unless Dagster's release notes explicitly document that path and the database backup has been restored.
