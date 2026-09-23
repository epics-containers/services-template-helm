#!/bin/bash
# Render the template from this checkout with one answers file, then run the
# generated repo's own CI script (pre-commit plus helm lint/template of every
# service) on the result.
#
# usage: tests/test_template.sh tests/answers/<name>.yml [output dir]

set -xe

answers=$(realpath "${1:?usage: $0 <answers file> [output dir]}")
template=$(realpath "$(dirname "${0}")/..")
out=${2:-$(mktemp -d)}

uvx copier copy --trust --defaults --vcs-ref HEAD \
    --data-file "${answers}" "${template}" "${out}"

cd "${out}"
git init --quiet
git add --all
git -c user.name=ci -c user.email=ci@example.com commit --quiet -m "rendered from template"

# the rendered repo is standalone with no remote: do not let the outer CI's
# PR variables make ci_verify.sh look for a base branch that does not exist
unset GITHUB_BASE_REF CI_MERGE_REQUEST_TARGET_BRANCH_NAME
bash ci_verify.sh
