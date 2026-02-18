#!/usr/bin/env bash
# update/02-navigate-to-edit.sh -- Navigate to the target page's edit form
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Update Step 2: Navigate to Edit Form ==="

navigate_to_edit_page "$TARGET_PAGE_ID"

# Verify the edit form loaded
if element_exists "$SEL_EDIT_FORM"; then
    echo "  Edit form loaded for page ${TARGET_PAGE_ID}."
else
    echo "  [error] Edit form not found!" >&2
    take_named_screenshot "error-no-edit-form"
    exit 1
fi

# Show the current page title
current_title=$($RODNEY_CMD js "document.querySelector('${SEL_PAGE_TITLE}')?.value || ''" 2>/dev/null || echo "")
echo "  Current page title: ${current_title:-'(empty)'}"

take_named_screenshot "update-02-edit-form"

echo "=== Update Step 2 complete ==="
