#!/usr/bin/env bash
set -euo pipefail

base_url="${1:?Usage: ./scripts/remote-smoke.sh https://PUBLIC_DOMAIN}"
template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${template_root}/scripts/smoke.sh" "${base_url}"

launch_payload="$(
  jq -n \
    --arg query '
      mutation Launch($executionParams: ExecutionParams!) {
        launchPipelineExecution(executionParams: $executionParams) {
          __typename
          ... on LaunchRunSuccess { run { runId status } }
          ... on PythonError { message }
        }
      }
    ' \
    '{
      query: $query,
      variables: {
        executionParams: {
          selector: {
            repositoryLocationName: "railway_starter",
            repositoryName: "__repository__",
            jobName: "daily_metrics_job"
          },
          runConfigData: {},
          mode: "default"
        }
      }
    }'
)"
launch_response="$(
  curl --fail --silent --show-error "${base_url}/graphql" \
    --header "content-type: application/json" \
    --data-binary "${launch_payload}"
)"
launch_type="$(jq -r '.data.launchPipelineExecution.__typename // "ERROR"' <<<"${launch_response}")"
if [[ "${launch_type}" != "LaunchRunSuccess" ]]; then
  echo "Dagster rejected the remote sample job: ${launch_type}" >&2
  jq -c '{errors, result: .data.launchPipelineExecution}' <<<"${launch_response}" >&2
  exit 1
fi
run_id="$(jq -r '.data.launchPipelineExecution.run.runId' <<<"${launch_response}")"

for attempt in $(seq 1 30); do
  status_payload="$(
    jq -n \
      --arg run_id "${run_id}" \
      --arg query '
        query Run($runId: ID!) {
          runOrError(runId: $runId) {
            __typename
            ... on Run { runId status }
            ... on RunNotFoundError { message }
          }
        }
      ' \
      '{query: $query, variables: {runId: $run_id}}'
  )"
  status="$(
    curl --fail --silent --show-error "${base_url}/graphql" \
      --header "content-type: application/json" \
      --data-binary "${status_payload}" |
      jq -r '.data.runOrError.status // .data.runOrError.__typename // "ERROR"'
  )"

  if [[ "${status}" == "SUCCESS" ]]; then
    echo "Remote queued Dagster run ${run_id} passed."
    exit 0
  fi

  if [[ "${status}" == "FAILURE" || "${status}" == "CANCELED" ]]; then
    echo "Remote queued Dagster run ${run_id} ended with ${status}." >&2
    exit 1
  fi

  if [[ "${attempt}" == "30" ]]; then
    echo "Remote queued Dagster run ${run_id} remained ${status}." >&2
    exit 1
  fi

  sleep 2
done
