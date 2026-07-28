#!/usr/bin/env bash
set -euo pipefail

template_id="${1:?Usage: ./scripts/audit-template.sh TEMPLATE_ID}"
template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_path="${template_root}/template-defaults.json"
railway_bin="${RAILWAY_BIN:-railway}"

command -v "${railway_bin}" >/dev/null
command -v jq >/dev/null

template_json="$(
  "${railway_bin}" api \
    'query AuditTemplate($id: String!) { template(id: $id) { id status serializedConfig } }' \
    --var "id=${template_id}" \
    --compact
)"
plan_json="$(
  "${railway_bin}" config plan \
    --file "${template_root}/.railway/railway.ts" \
    --runner "${template_root}/node_modules/railway/dist/iac/bin.js" \
    --json
)"

jq -e '.data.template.serializedConfig.services | type == "object"' \
  <<<"${template_json}" >/dev/null || {
  echo "Template ${template_id} has no serialized service configuration." >&2
  exit 1
}

expected_services=$'Dagster Daemon\nDagster Webserver\nPostgreSQL'
actual_services="$(
  jq -r '.data.template.serializedConfig.services | [.[] | .name] | sort | join("\n")' \
    <<<"${template_json}"
)"
if [[ "${actual_services}" != "${expected_services}" ]]; then
  echo "Template service names do not match the Dagster topology." >&2
  exit 1
fi

failures=0
mapfile -t services < <(jq -r 'keys[]' "${expected_path}")
for service_name in "${services[@]}"; do
  expected_resource="$(
    jq -c --arg service "${service_name}" \
      '.desiredGraph.resources[] | select(.type == "service" and .name == $service)' \
      <<<"${plan_json}"
  )"
  actual_service="$(
    jq -c --arg service "${service_name}" \
      '[.data.template.serializedConfig.services[] | select(.name == $service)][0]' \
      <<<"${template_json}"
  )"

  for field in branch rootDirectory; do
    expected_value="$(jq -r --arg field "${field}" '.source[$field]' <<<"${expected_resource}")"
    actual_value="$(jq -r --arg field "${field}" '.source[$field]' <<<"${actual_service}")"
    if [[ "${actual_value}" != "${expected_value}" ]]; then
      echo "${service_name}: source ${field} does not match IaC." >&2
      failures=$((failures + 1))
    fi
  done

  expected_repo="$(jq -r '.source.repo' <<<"${expected_resource}")"
  actual_repo="$(
    jq -r '.source.repo | sub("^https://github.com/"; "") | sub("\\.git$"; "")' \
      <<<"${actual_service}"
  )"
  if [[ "${actual_repo}" != "${expected_repo}" ]]; then
    echo "${service_name}: source repo does not match IaC." >&2
    failures=$((failures + 1))
  fi

  expected_start="$(jq -r '.deploy.startCommand' <<<"${expected_resource}")"
  actual_start="$(jq -r '.deploy.startCommand' <<<"${actual_service}")"
  if [[ "${actual_start}" != "${expected_start}" ]]; then
    echo "${service_name}: start command does not match IaC." >&2
    failures=$((failures + 1))
  fi

  mapfile -t variables < <(
    jq -c --arg service "${service_name}" '.[$service] | to_entries[]' "${expected_path}"
  )
  for variable in "${variables[@]}"; do
    variable_name="$(jq -r '.key' <<<"${variable}")"
    expected_value="$(jq -r '.value' <<<"${variable}")"
    actual_value="$(
      jq -r --arg variable "${variable_name}" \
        '.variables[$variable].defaultValue // "__MISSING__"' <<<"${actual_service}"
    )"
    is_optional="$(
      jq -r --arg variable "${variable_name}" \
        '.variables[$variable].isOptional // false' <<<"${actual_service}"
    )"

    if [[ "${actual_value}" != "${expected_value}" ]]; then
      echo "${service_name}.${variable_name}: default is missing or incorrect." >&2
      failures=$((failures + 1))
    fi
    if [[ "${is_optional}" != "false" ]]; then
      echo "${service_name}.${variable_name}: variable must remain required." >&2
      failures=$((failures + 1))
    fi
  done
done

web_domain="$(
  jq -r '
    [.data.template.serializedConfig.services[]
      | select(.name == "Dagster Webserver")
      | .networking.serviceDomains
      | has("<hasDomain>")][0] // false
  ' <<<"${template_json}"
)"
daemon_domain="$(
  jq -r '
    [.data.template.serializedConfig.services[]
      | select(.name == "Dagster Daemon")
      | (.networking.serviceDomains | length == 0)][0] // false
  ' <<<"${template_json}"
)"
if [[ "${web_domain}" != "true" ]]; then
  echo "Dagster Webserver public networking is not enabled." >&2
  failures=$((failures + 1))
fi
if [[ "${daemon_domain}" != "true" ]]; then
  echo "Dagster Daemon must remain private." >&2
  failures=$((failures + 1))
fi

if (( failures > 0 )); then
  echo "Template audit failed with ${failures} configuration error(s)." >&2
  exit 1
fi

echo "Template ${template_id} matches the pinned source, topology, variables, commands, and networking."
