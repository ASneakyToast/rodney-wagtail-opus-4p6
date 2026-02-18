#!/usr/bin/env bash
# update/01-login.sh -- Login to Wagtail admin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-login.sh"

echo "=== Update Step 1: Login ==="

ensure_browser
wagtail_login

# Verify we're on the admin dashboard
check_url_contains "/admin/"
take_named_screenshot "update-01-dashboard"

echo "=== Update Step 1 complete ==="
