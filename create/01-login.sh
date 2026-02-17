#!/usr/bin/env bash
# create/01-login.sh -- Start browser and log in to Wagtail admin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-login.sh"

echo "=== Create Step 1: Login ==="

ensure_browser
wagtail_login

# Verify we're on the dashboard
check_url_contains "/admin/" || true
take_named_screenshot "create-01-dashboard"

echo "=== Create Step 1 complete ==="
