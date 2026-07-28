#!/usr/bin/env bash
set -euo pipefail

template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  ".dockerignore"
  ".env.example"
  ".railway/railway.ts"
  "CHANGELOG.md"
  "Dockerfile"
  "MARKETPLACE.md"
  "PUBLISHING.md"
  "README.md"
  "SUPPORT.md"
  "UPGRADE.md"
  "VERSION"
  "app/definitions.py"
  "compose.yaml"
  "dagster.yaml"
  "requirements.txt"
  "scripts/audit-template.sh"
  "scripts/daemon_health.py"
  "scripts/remote-smoke.sh"
  "scripts/smoke.sh"
  "scripts/start.sh"
  "template-defaults.json"
  "tests/test_daemon_health.py"
  "tests/test_definitions.py"
  "workspace.yaml"
)

for file in "${required_files[@]}"; do
  test -f "${template_root}/${file}" || {
    echo "Missing required file: ${file}" >&2
    exit 1
  }
done

template_version="$(<"${template_root}/VERSION")"
semver_pattern='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
if [[ ! "${template_version}" =~ ${semver_pattern} ]]; then
  echo "VERSION must contain one stable MAJOR.MINOR.PATCH version." >&2
  exit 1
fi
grep -Fq "## [${template_version}]" "${template_root}/CHANGELOG.md" || {
  echo "CHANGELOG.md has no entry for ${template_version}." >&2
  exit 1
}

if find "${template_root}" -type f \( -name ".env" -o -name "*.local" \) -print -quit | grep -q .; then
  echo "Local secret file found in the template directory" >&2
  exit 1
fi

docker compose -f "${template_root}/compose.yaml" config --quiet
jq empty "${template_root}/template-defaults.json"
bash -n \
  "${template_root}/scripts/audit-template.sh" \
  "${template_root}/scripts/remote-smoke.sh" \
  "${template_root}/scripts/smoke.sh" \
  "${template_root}/scripts/start.sh"
python3 -c \
  "compile(open('${template_root}/scripts/daemon_health.py', encoding='utf-8').read(), 'scripts/daemon_health.py', 'exec')"

grep -Fq "dagster==1.13.15" "${template_root}/requirements.txt"
grep -Fq "max_concurrent_runs: 1" "${template_root}/dagster.yaml"
grep -Fq "class: DefaultRunLauncher" "${template_root}/dagster.yaml"

if grep -Rqs "/var/run/docker.sock\\|DockerRunLauncher" \
  "${template_root}/.railway" \
  "${template_root}/app" \
  "${template_root}/compose.yaml" \
  "${template_root}/dagster.yaml" \
  "${template_root}/Dockerfile" \
  "${template_root}/scripts/start.sh"; then
  echo "The template must not require a Docker socket or DockerRunLauncher" >&2
  exit 1
fi

echo "Dagster template structure and Compose configuration are valid."
