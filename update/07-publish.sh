#!/usr/bin/env bash
# update/07-publish.sh -- Save as draft, verify, then publish the updated page
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

echo "=== Update Step 7: Publish ==="

# Step 1: Save as draft first (safer -- preserves content before publishing)
echo "  Saving as draft..."

if element_exists "$SEL_ACTION_DRAFT" 2>/dev/null; then
    rodney_cmd click "$SEL_ACTION_DRAFT"
elif element_exists "$SEL_ACTION_MENU_TOGGLE" 2>/dev/null; then
    rodney_cmd click "$SEL_ACTION_MENU_TOGGLE"
    $RODNEY_CMD waitstable
    if element_exists "$SEL_ACTION_DRAFT" 2>/dev/null; then
        rodney_cmd click "$SEL_ACTION_DRAFT"
    else
        echo "  [info] Draft button not found in dropdown, using form submit..."
        $RODNEY_CMD js "document.querySelector('${SEL_EDIT_FORM}')?.querySelector('button[type=\"submit\"]')?.click()"
    fi
else
    echo "  [info] Draft button not found, using form submit..."
    $RODNEY_CMD js "document.querySelector('${SEL_EDIT_FORM}')?.querySelector('button[type=\"submit\"]')?.click()"
fi

wait_for_page
take_named_screenshot "update-07-draft-saved"

# Check for success message
if element_exists "$SEL_SUCCESS_MESSAGE" 2>/dev/null; then
    success_msg=$(safe_text "$SEL_SUCCESS_MESSAGE")
    echo "  Draft saved: ${success_msg}"
else
    echo "  [warn] No success message detected after saving draft."
    error_msg=$($RODNEY_CMD js "
        const errors = document.querySelectorAll('.error-message, .help-block.help-critical, .w-field__errors');
        return Array.from(errors).map(e => e.textContent.trim()).join('; ') || 'no errors found';
    " 2>/dev/null || echo "")
    if [[ -n "$error_msg" ]] && [[ "$error_msg" != "no errors found" ]]; then
        echo "  [error] Form errors: ${error_msg}" >&2
        take_named_screenshot "error-update-form-validation"
        exit 1
    fi
fi

# Step 2: Now publish
echo "  Publishing page..."

if element_exists "$SEL_ACTION_PUBLISH" 2>/dev/null; then
    rodney_cmd click "$SEL_ACTION_PUBLISH"
elif element_exists "$SEL_ACTION_MENU_TOGGLE" 2>/dev/null; then
    rodney_cmd click "$SEL_ACTION_MENU_TOGGLE"
    $RODNEY_CMD waitstable

    if element_exists "$SEL_ACTION_PUBLISH" 2>/dev/null; then
        rodney_cmd click "$SEL_ACTION_PUBLISH"
    else
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
take_named_screenshot "update-07-published"

# Verify publish succeeded
if element_exists "$SEL_SUCCESS_MESSAGE" 2>/dev/null; then
    success_msg=$(safe_text "$SEL_SUCCESS_MESSAGE")
    echo "  Published: ${success_msg}"
else
    echo "  [info] No success message detected. Page may still have been published."
fi

# Get the current URL
final_url=$($RODNEY_CMD url)
echo "  Final URL: ${final_url}"

echo ""
echo "=== Update Step 7 complete -- Page updated and published! ==="
