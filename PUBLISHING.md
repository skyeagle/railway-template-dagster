# Publishing the Dagster template

The template is published at `https://railway.com/deploy/dagster`. Its Railway template ID is `03d12173-a2b4-4ebc-bb7d-a6ea683f4a22`, and its deployment code is `dagster`.

Both application services build from the public `tech-progress/railway-template-dagster` repository's `release-v1` branch. The current template release is `v1.0.0`. Tag each verified release with SemVer, then move the matching major release branch only as an explicit template release because connected Railway services may autodeploy branch updates.

Before moving the release branch, update `VERSION` and `CHANGELOG.md`, verify the standalone mirror, and create the release tags:

```bash
version="$(<VERSION)"
git tag -a "v${version}" -m "Dagster Railway template v${version}"
git push origin "v${version}"
git push origin "main:release-v${version%%.*}"
```

The private authoring monorepo records the same release with the namespaced tag `dagster-v${version}`.

Create a disposable project, apply the Railway configuration, generate a public domain for `Dagster Webserver` on port 3000, and wait for all three deployments:

```bash
railway init --name Dagster --json
railway config apply --yes
railway domain --service "Dagster Webserver" --port 3000 --json
```

Run an application-level smoke test against the generated domain. It submits a real queued job through Dagster's GraphQL API, then polls the run until the private daemon completes it:

```bash
./scripts/remote-smoke.sh https://PUBLIC_DOMAIN
```

Confirm that the webserver and daemon replicas are currently running, inspect their memory after a soak, then create the template. Complete any literal defaults removed by `railway templates create`, and audit the stored draft before publication:

```bash
railway templates create --project <PROJECT_ID> --environment <ENVIRONMENT_ID> --json
./scripts/audit-template.sh <TEMPLATE_ID>
railway templates publish <TEMPLATE_ID> \
  --category Automation \
  --description "Deploy Dagster with a webserver, daemon, example asset job, and PostgreSQL." \
  --readme-file MARKETPLACE.md \
  --json
```

After publication, stop every service in the disposable project. Record the project, environment, template, deployment code, verification evidence, and shutdown evidence in the monorepo's `dagster/FINDINGS.md`; do not copy that evidence file into the public distribution repository.
