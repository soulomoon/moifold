#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
cd "${repo_root}"

sdist_dir="dist-newstyle/sdist"

packages=(
  "agent-workflow-core:agent-workflow-core:0.1.0.0:agent-workflow-core.cabal"
  "agent-workflow-codex:agent-workflow-codex:0.1.0.0:agent-workflow-codex.cabal"
  "agent-workflow-github:agent-workflow-github:0.1.0.0:agent-workflow-github.cabal"
)

echo "Repository root: ${repo_root}"

for package_spec in "${packages[@]}"; do
  IFS=: read -r package_dir package_name package_version cabal_file <<< "${package_spec}"
  echo "+ (cd ${package_dir} && cabal check)"
  (cd "${package_dir}" && cabal check)
done

mkdir -p "${sdist_dir}"

for package_spec in "${packages[@]}"; do
  IFS=: read -r _package_dir package_name _package_version _cabal_file <<< "${package_spec}"
  echo "+ cabal sdist --output-directory=${sdist_dir} ${package_name}"
  cabal sdist --output-directory="${sdist_dir}" "${package_name}"
done

echo "Validating source distributions:"
for package_spec in "${packages[@]}"; do
  IFS=: read -r _package_dir package_name package_version cabal_file <<< "${package_spec}"
  package_root="${package_name}-${package_version}"
  artifact="${sdist_dir}/${package_root}.tar.gz"

  echo "+ test -f ${artifact}"
  test -f "${artifact}"

  echo "+ tar -tzf ${artifact} | rg '^${package_root}/'"
  tar -tzf "${artifact}" | rg "^${package_root}/" >/dev/null

  echo "+ tar -tzf ${artifact} | rg -Fx '${package_root}/${cabal_file}'"
  tar -tzf "${artifact}" | rg -Fx "${package_root}/${cabal_file}" >/dev/null
done

echo "Workflow package source distributions:"
for package_spec in "${packages[@]}"; do
  IFS=: read -r _package_dir package_name package_version _cabal_file <<< "${package_spec}"
  echo "- ${sdist_dir}/${package_name}-${package_version}.tar.gz"
done

echo "No upload or package publication command was run."
