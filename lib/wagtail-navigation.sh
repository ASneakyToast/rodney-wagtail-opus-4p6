#!/usr/bin/env bash
# lib/wagtail-navigation.sh -- Navigate the Wagtail page explorer
# Source after config/env.sh, config/selectors.sh, and lib/rodney-helpers.sh

# Navigate to a specific page in the explorer by ID
navigate_to_page() {
    local page_id="$1"
    echo "  Navigating to page $page_id..."
    rodney_cmd open "${WAGTAIL_ADMIN_URL}/pages/${page_id}/"
    wait_for_page
}

# Navigate to the EDIT form of an existing page by ID
navigate_to_edit_page() {
    local page_id="${1:-$TARGET_PAGE_ID}"
    echo "  Navigating to edit page $page_id..."
    rodney_cmd open "${WAGTAIL_ADMIN_URL}/pages/${page_id}/edit/"
    wait_for_page
}

# Navigate to the "Add child page" screen for a given parent
navigate_to_add_subpage() {
    local parent_id="${1:-$PARENT_PAGE_ID}"
    echo "  Navigating to add_subpage for parent $parent_id..."
    rodney_cmd open "${WAGTAIL_ADMIN_URL}/pages/${parent_id}/add_subpage/"
    wait_for_page
}

# Select a page type from the "choose page type" screen
select_page_type() {
    local app_label="${1:-$PAGE_TYPE_APP_LABEL}"
    local model="${2:-$PAGE_TYPE_MODEL}"

    echo "  Selecting page type: ${app_label}.${model}..."

    # Build a selector that matches the link to the create form for this page type
    local selector="a[href*=\"add/${app_label}/${model}/\"]"

    if ! element_exists "$selector"; then
        echo "  [error] Page type link not found: $selector" >&2
        echo "  Available page types on this screen:" >&2
        $RODNEY_CMD html 'main' 2>/dev/null | head -50 >&2
        take_named_screenshot "error-page-type-not-found"
        return 1
    fi

    rodney_wait_and_click "$selector"
    wait_for_page

    # Verify we landed on the create form
    if ! element_exists "$SEL_EDIT_FORM"; then
        echo "  [warn] Page edit form not found after selecting page type." >&2
        take_named_screenshot "warn-no-edit-form"
    fi

    echo "  Page type selected. On create form."
}

# Navigate directly to the create page form
navigate_to_create_page() {
    local parent_id="${1:-$PARENT_PAGE_ID}"
    local app_label="${2:-$PAGE_TYPE_APP_LABEL}"
    local model="${3:-$PAGE_TYPE_MODEL}"

    echo "  Navigating directly to create page form..."
    # Wagtail URL pattern: /admin/pages/add/{app}/{model}/{parent_id}/
    rodney_cmd open "${WAGTAIL_ADMIN_URL}/pages/add/${app_label}/${model}/${parent_id}/"
    wait_for_page
}

# Get the page tree listing as text
get_page_tree() {
    echo "  Reading page tree..."
    $RODNEY_CMD text "$SEL_PAGE_LISTING" 2>/dev/null || echo "(empty or not found)"
}
