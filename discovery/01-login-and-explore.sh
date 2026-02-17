#!/usr/bin/env bash
# discovery/01-login-and-explore.sh -- Login and explore the Wagtail page tree
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

# Navigate to page explorer root
echo "  Navigating to page explorer..."
rodney_cmd open "${WAGTAIL_ADMIN_URL}/pages/"
wait_for_page
take_named_screenshot "discovery-01-page-explorer-root"

# Get the page tree
echo ""
echo "--- Page Tree ---"
get_page_tree
echo "-----------------"
echo ""

# Navigate to the target parent page
navigate_to_page "$PARENT_PAGE_ID"
take_named_screenshot "discovery-01-parent-page"

echo "  Listing child pages under parent ${PARENT_PAGE_ID}:"
get_page_tree

# Capture the parent page title
parent_title=$(safe_text 'h1, .w-header__title, header h1')
echo "  Parent page title: ${parent_title:-'(not found)'}"

echo ""
echo "=== Discovery Step 1 complete ==="
