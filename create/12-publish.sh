#!/usr/bin/env bash
# create/12-publish.sh -- Save as draft, verify, then publish
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

echo "=== Create Step 12: Publish ==="

# Step 1: Save as draft first (safer -- preserves content before publishing)
echo "  Saving as draft..."

# Wagtail 6.x uses a split button with a dropdown. The default action may vary.
# Try direct draft button first
if element_exists "$SEL_ACTION_DRAFT"; then
    rodney_cmd click "$SEL_ACTION_DRAFT"
elif element_exists "$SEL_ACTION_MENU_TOGGLE"; then
    # Open the action dropdown to find "Save draft"
    rodney_cmd click "$SEL_ACTION_MENU_TOGGLE"
    $RODNEY_CMD waitstable
    rodney_cmd click "$SEL_ACTION_DRAFT"
else
    # Fallback: try clicking the main submit button (saves as draft by default)
    echo "  [info] Draft button not found, using form submit..."
    $RODNEY_CMD js "document.querySelector('${SEL_EDIT_FORM}').querySelector('button[type=\"submit\"]')?.click()"
fi

wait_for_page
take_named_screenshot "create-12-draft-saved"

# Check for success message
if element_exists "$SEL_SUCCESS_MESSAGE"; then
    success_msg=$(safe_text "$SEL_SUCCESS_MESSAGE")
    echo "  Draft saved: ${success_msg}"
else
    echo "  [warn] No success message detected after saving draft."
    # Check for errors
    error_msg=$($RODNEY_CMD js "
        const errors = document.querySelectorAll('.error-message, .help-block.help-critical, .w-field__errors');
        return Array.from(errors).map(e => e.textContent.trim()).join('; ') || 'no errors found';
    " 2>/dev/null || echo "")
    if [[ -n "$error_msg" ]] && [[ "$error_msg" != "no errors found" ]]; then
        echo "  [error] Form errors: ${error_msg}" >&2
        take_named_screenshot "error-form-validation"
        exit 1
    fi
fi

# Step 2: Now publish
echo "  Publishing page..."

# We should be on the edit page after saving draft. Find the publish button.
if element_exists "$SEL_ACTION_PUBLISH"; then
    rodney_cmd click "$SEL_ACTION_PUBLISH"
elif element_exists "$SEL_ACTION_MENU_TOGGLE"; then
    # Open dropdown and find publish
    rodney_cmd click "$SEL_ACTION_MENU_TOGGLE"
    $RODNEY_CMD waitstable

    if element_exists "$SEL_ACTION_PUBLISH"; then
        rodney_cmd click "$SEL_ACTION_PUBLISH"
    else
        # Try finding by text
        $RODNEY_CMD js "
            const btns = document.querySelectorAll('button');
            const pub = Array.from(btns).find(b => b.textContent.trim().toLowerCase().includes('publish'));
            if (pub) pub.click();
        "
    fi
else
    echo "  [error] Publish button not found!" >&2
    take_named_screenshot "error-no-publish-button"
    exit 1
fi

wait_for_page
take_named_screenshot "create-12-published"

# Verify publish succeeded
if element_exists "$SEL_SUCCESS_MESSAGE"; then
    success_msg=$(safe_text "$SEL_SUCCESS_MESSAGE")
    echo "  Published: ${success_msg}"
else
    echo "  [info] No success message detected. Page may still have been published."
fi

# Get the current URL (should be the page edit or explorer)
final_url=$($RODNEY_CMD url)
echo "  Final URL: ${final_url}"

echo ""
echo "=== Create Step 12 complete -- Page published! ==="
