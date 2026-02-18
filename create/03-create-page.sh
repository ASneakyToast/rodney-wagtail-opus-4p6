#!/usr/bin/env bash
# create/03-create-page.sh -- Create a new child page of the configured type
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Create Step 3: Create Page ==="

# Navigate directly to the create form
# URL pattern: /admin/pages/add/{app}/{model}/{parent_id}/
navigate_to_create_page "$PARENT_PAGE_ID" "$PAGE_TYPE_APP_LABEL" "$PAGE_TYPE_MODEL"

# Verify the edit form loaded
if element_exists "$SEL_EDIT_FORM"; then
    echo "  Page creation form loaded."
else
    echo "  [warn] Edit form not detected. May need to select page type first."
    # Try the two-step approach: add_subpage -> select type
    navigate_to_add_subpage "$PARENT_PAGE_ID"
    select_page_type "$PAGE_TYPE_APP_LABEL" "$PAGE_TYPE_MODEL"
fi

take_named_screenshot "create-03-blank-form"

echo "=== Create Step 3 complete ==="
