#!/usr/bin/env bash
set -euo pipefail

# Lists every SKILL.md path in this repo, relative to the repo root.
#
# Adapted from https://github.com/mattpocock/skills/blob/main/scripts/list-skills.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO"
find plugins/bitbucket-skills/skills -name SKILL.md | sort
