#!/usr/bin/env bash
# discovery/01-login-and-explore.sh -- Login and explore the target page
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-login.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Discovery Step 1: Login and Explore ==="

ensure_browser
wagtail_login

# Navigate to the target page in the explorer
echo "  Navigating to target page ${TARGET_PAGE_ID}..."
navigate_to_page "$TARGET_PAGE_ID"
take_named_screenshot "discovery-01-target-page"

# Capture the target page title
target_title=$(safe_text 'h1, .w-header__title, header h1')
echo "  Target page title: ${target_title:-'(not found)'}"

# List child pages under the target
echo ""
echo "--- Child Pages Under Target ---"
get_page_tree
echo "--------------------------------"

echo ""
echo "=== Discovery Step 1 complete ==="
