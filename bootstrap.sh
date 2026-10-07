#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

role="${1:-}"
if [ -z "$role" ] || [ ! -d "roles/$role" ]; then
  echo "Usage: ./bootstrap.sh <role>"
  echo "Roles: $(ls roles | tr '\n' ' ')"
  exit 1
fi

bash common/setup.sh
bash "roles/$role/setup.sh"
