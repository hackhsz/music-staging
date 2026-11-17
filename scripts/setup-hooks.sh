#!/bin/sh
set -e
root=$(git rev-parse --show-toplevel)
git -C "$root" config core.hooksPath .githooks
chmod +x "$root/.githooks/"* "$root/scripts/"*.sh 2>/dev/null || true
echo "Hooks enabled: core.hooksPath=.githooks"
