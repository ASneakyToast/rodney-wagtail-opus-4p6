#!/usr/bin/env bash
# lib/image-helpers.sh -- Wagtail image chooser interaction helpers
# Handles searching for existing images in the media library and selecting them.
#
# Wagtail 6.x image chooser flow (confirmed via live testing):
#   1. Click [data-chooser-action-choose] button inside the block field
#   2. A [role="dialog"] modal opens with search (#id_q) + image grid
#   3. Type search term in #id_q, submit via form.requestSubmit()
#   4. Results appear as a.image-choice links
#   5. Click a.image-choice to select — modal closes, preview appears
#
# Source after config/env.sh, config/selectors.sh, and lib/rodney-helpers.sh

# Choose an image from the Wagtail media library by searching for a keyword.
# Opens the chooser modal, searches, and selects the first result.
#
# Usage: choose_image_for_field "$block_selector" "image" "DMBA students"
# Args:
#   $1 - parent block CSS selector
#   $2 - field name (contentpath) within the block, e.g. "image"
#   $3 - search keyword to find the image
choose_image_for_field() {
    local block_selector="$1"
    local field_name="$2"
    local search_term="$3"

    echo "  Choosing image for field '${field_name}' (search: '${search_term}')..."

    # Step 1: Click the "Choose an image" button inside the field
    # Use rodney click directly — the button is [data-chooser-action-choose]
    # scoped within the block's image contentpath field.
    local chooser_sel="${block_selector} [data-contentpath=\"${field_name}\"] [data-chooser-action-choose]"

    if ! $RODNEY_CMD click "$chooser_sel" 2>/dev/null; then
        echo "  [warn] Could not click image chooser button at: ${chooser_sel}" >&2
        # Try JS fallback for cases where pointer-events might be 'none'
        local js_result
        js_result=$($RODNEY_CMD js "
            (() => {
                const btn = document.querySelector('${chooser_sel}');
                if (!btn) return 'no-btn';
                btn.click();
                return 'clicked';
            })()
        " 2>/dev/null || echo "error")
        if [[ "$js_result" != "clicked" ]]; then
            echo "  [warn] JS click also failed: ${js_result}" >&2
            return 1
        fi
    fi

    sleep 2
    $RODNEY_CMD waitstable 2>/dev/null

    # Step 2: Verify the modal opened (look for #id_q which is the modal search input)
    local modal_check
    modal_check=$($RODNEY_CMD js "document.querySelector('#id_q') ? 'open' : 'closed'" 2>/dev/null || echo "error")
    if [[ "$modal_check" != "open" ]]; then
        echo "  [warn] Image chooser modal did not open (no #id_q found)" >&2
        take_named_screenshot "error-no-image-modal"
        return 1
    fi

    take_named_screenshot "image-chooser-modal-open"

    # Step 3: Search for the image using #id_q + form.requestSubmit()
    $RODNEY_CMD clear '#id_q' 2>/dev/null
    $RODNEY_CMD input '#id_q' "$search_term" 2>/dev/null
    sleep 1

    # Submit the form properly (requestSubmit triggers validation + submission)
    $RODNEY_CMD js "document.querySelector('#id_q').closest('form').requestSubmit()" 2>/dev/null

    sleep 3
    $RODNEY_CMD waitstable 2>/dev/null
    take_named_screenshot "image-chooser-search-results"

    # Step 4: Select the first result image (a.image-choice links)
    local result_count
    result_count=$($RODNEY_CMD js "document.querySelectorAll('a.image-choice').length" 2>/dev/null || echo "0")

    if [[ "$result_count" == "0" ]] || [[ "$result_count" == "null" ]]; then
        echo "  [warn] No image results for '${search_term}' — trying without search..." >&2
        # Try selecting from the "Latest images" that appear before searching
        result_count=$($RODNEY_CMD js "document.querySelectorAll('a.image-choice').length" 2>/dev/null || echo "0")
        if [[ "$result_count" == "0" ]]; then
            echo "  [warn] No images available at all" >&2
            _close_image_chooser_modal
            return 1
        fi
    fi

    echo "  Found ${result_count} image results for '${search_term}', selecting first..."

    # Click the first result
    if $RODNEY_CMD click 'a.image-choice' 2>/dev/null; then
        sleep 2
        $RODNEY_CMD waitstable 2>/dev/null
        echo "  Image selected for field '${field_name}'."
        take_named_screenshot "image-chosen-${field_name}"
        return 0
    fi

    # JS fallback for clicking
    local click_result
    click_result=$($RODNEY_CMD js "
        (() => {
            const link = document.querySelector('a.image-choice');
            if (!link) return 'no-link';
            link.click();
            return 'clicked';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$click_result" == "clicked" ]]; then
        sleep 2
        $RODNEY_CMD waitstable 2>/dev/null
        echo "  Image selected (JS fallback) for field '${field_name}'."
        take_named_screenshot "image-chosen-${field_name}"
        return 0
    fi

    echo "  [warn] Could not select image: ${click_result}" >&2
    take_named_screenshot "error-no-image-results"
    _close_image_chooser_modal
    return 1
}

# Close any open image chooser modal (cleanup on failure)
_close_image_chooser_modal() {
    # Try the X close button first, then Escape key
    $RODNEY_CMD js "
        (() => {
            const closeBtn = document.querySelector(
                'button[aria-label=\"Close\"], ' +
                '[role=\"dialog\"] button[aria-label=\"Close\"], ' +
                '.w-dialog button[aria-label=\"Close\"]'
            );
            if (closeBtn) { closeBtn.click(); return 'closed'; }
            document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
            return 'escaped';
        })()
    " 2>/dev/null || true
    sleep 1
    $RODNEY_CMD waitstable 2>/dev/null || true
}

# Detect if a block has an image field (by checking for chooser widgets)
# Usage: has_image_field "$block_selector" "image"
# Returns: "yes" or "no" via stdout
has_image_field() {
    local block_selector="$1"
    local field_name="${2:-image}"

    $RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_selector}');
            if (!block) return 'no';
            const field = block.querySelector('[data-contentpath=\"${field_name}\"]');
            if (!field) return 'no';
            const isChooser = field.querySelector(
                '[data-chooser-action-choose], .chooser__choose-button, .image-chooser'
            );
            return isChooser ? 'yes' : 'no';
        })()
    " 2>/dev/null || echo "no"
}

# List all fields in a block (useful for discovery/debugging)
# Returns JSON array of field names and types
# Usage: list_block_fields "$block_selector"
list_block_fields() {
    local block_selector="$1"

    $RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_selector}');
            if (!block) return '[]';

            const fields = block.querySelectorAll('[data-contentpath]');
            const result = [];
            fields.forEach(f => {
                const cp = f.getAttribute('data-contentpath');
                if (cp && cp.length < 40) {
                    const hasDraftail = !!f.querySelector('.Draftail-Editor');
                    const hasInput = !!f.querySelector('input:not([type=hidden])');
                    const hasTextarea = !!f.querySelector('textarea');
                    const hasChooser = !!f.querySelector('[data-chooser-action-choose], .chooser__choose-button');
                    const hasSelect = !!f.querySelector('select');

                    let fieldType = 'unknown';
                    if (hasDraftail) fieldType = 'richtext';
                    else if (hasChooser) fieldType = 'chooser';
                    else if (hasInput) fieldType = 'text';
                    else if (hasTextarea) fieldType = 'textarea';
                    else if (hasSelect) fieldType = 'select';

                    result.push({ name: cp, type: fieldType });
                }
            });
            return JSON.stringify(result);
        })()
    " 2>/dev/null || echo "[]"
}
