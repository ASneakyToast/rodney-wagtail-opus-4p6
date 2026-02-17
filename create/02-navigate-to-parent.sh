#!/usr/bin/env bash
# create/02-navigate-to-parent.sh -- Navigate to the parent page in the explorer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Create Step 2: Navigate to Parent Page ==="

navigate_to_page "$PARENT_PAGE_ID"

parent_title=$(safe_text 'h1, .w-header__title, header h1')
echo "  Parent page: ${parent_title:-'(title not found)'}"

take_named_screenshot "create-02-parent-page"

echo "=== Create Step 2 complete ==="
