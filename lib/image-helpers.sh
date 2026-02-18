#!/usr/bin/env bash
# lib/image-helpers.sh -- Wagtail image chooser interaction helpers
# Handles searching for existing images in the media library and selecting them.
#
# Wagtail's image chooser widget pattern:
#   1. Click "Choose an image" button inside the block field
#   2. A modal opens with search + image grid
#   3. Search for an image by keyword
#   4. Click the matching image to select it
#   5. Modal closes and image preview appears in the field
#
# Source after config/env.sh, config/selectors.sh, and lib/rodney-helpers.sh

# Choose an image from the Wagtail media library by searching for a keyword.
# Looks for an image chooser widget inside a block's named field, opens the
# chooser modal, searches, and selects the first result.
#
# Usage: choose_image_for_field "$block_selector" "image" "DMBA students"
# Args:
#   $1 - parent block CSS selector
#   $2 - field name (contentpath) within the block, e.g. "image", "photo"
#   $3 - search keyword to find the image
# Returns: "ok" on success, descriptive error otherwise
choose_image_for_field() {
    local block_selector="$1"
    local field_name="$2"
    local search_term="$3"

    echo "  Choosing image for field '${field_name}' (search: '${search_term}')..."

    # Step 1: Find and click the "Choose an image" button inside the field
    local chooser_result
    chooser_result=$($RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_selector}');
            if (!block) return 'no-block';

            // Try field-scoped selector first
            let fieldEl = block.querySelector('[data-contentpath=\"${field_name}\"]');
            if (!fieldEl) {
                // Might be directly on the block (e.g., single image field)
                fieldEl = block;
            }

            // Look for the chooser trigger button
            const btn = fieldEl.querySelector(
                'button[data-chooser-url*=\"image\"], ' +
                'button.image-chooser, ' +
                'button[id*=\"image\"][id*=\"chooser\"], ' +
                'button.chooser__choose-button, ' +
                '[data-chooser-action-choose], ' +
                'button:not([type=\"hidden\"])'
            );

            if (!btn) {
                // Check if there's a chooser widget link instead
                const link = fieldEl.querySelector(
                    'a[data-chooser-url*=\"image\"], ' +
                    'a.image-chooser'
                );
                if (link) { link.click(); return 'clicked-link'; }
                return 'no-chooser-btn';
            }

            btn.click();
            return 'clicked';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$chooser_result" != "clicked" ]] && [[ "$chooser_result" != "clicked-link" ]]; then
        echo "  [warn] Could not click image chooser: ${chooser_result}" >&2
        return 1
    fi

    sleep 2
    $RODNEY_CMD waitstable

    # Step 2: Wait for the modal to appear and find the search input
    local modal_found
    modal_found=$($RODNEY_CMD js "
        (() => {
            // Wagtail image chooser modal selectors
            const modal = document.querySelector(
                '.modal--image-chooser, ' +
                '#image-chooser-modal, ' +
                '[data-chooser-modal], ' +
                '.w-dialog--image-chooser, ' +
                '.chooser-modal'
            );
            if (modal) return 'modal';

            // Check for any open modal with an image tab/search
            const anyModal = document.querySelector(
                '.modal.fade.in, .modal.show, ' +
                '[role=\"dialog\"][aria-modal=\"true\"], ' +
                '.w-dialog[open]'
            );
            if (anyModal) return 'generic-modal';

            return 'no-modal';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$modal_found" == "no-modal" ]]; then
        echo "  [warn] Image chooser modal did not appear" >&2
        take_named_screenshot "error-no-image-modal"
        return 1
    fi

    take_named_screenshot "image-chooser-modal-open"

    # Step 3: Search for the image
    local search_result
    search_result=$($RODNEY_CMD js "
        (() => {
            // Find the search input in the modal
            const searchInput = document.querySelector(
                '.modal.show input[type=\"search\"], ' +
                '.modal.show input[name=\"q\"], ' +
                '.modal.show input[placeholder*=\"Search\"], ' +
                '[role=\"dialog\"] input[type=\"search\"], ' +
                '[role=\"dialog\"] input[name=\"q\"], ' +
                '.w-dialog input[type=\"search\"], ' +
                '.w-dialog input[name=\"q\"], ' +
                '#id_q'
            );
            if (!searchInput) return 'no-search-input';

            // Clear and type search term
            searchInput.value = '';
            searchInput.dispatchEvent(new Event('input', { bubbles: true }));
            searchInput.value = '${search_term}';
            searchInput.dispatchEvent(new Event('input', { bubbles: true }));
            searchInput.dispatchEvent(new Event('change', { bubbles: true }));

            // Submit the search form if there is one
            const form = searchInput.closest('form');
            if (form) {
                form.dispatchEvent(new Event('submit', { bubbles: true }));
            }
            // Also try pressing Enter
            searchInput.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));

            return 'searched';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$search_result" != "searched" ]]; then
        echo "  [warn] Could not search for image: ${search_result}" >&2
        # Try selecting the first available image anyway
    fi

    sleep 2
    $RODNEY_CMD waitstable
    take_named_screenshot "image-chooser-search-results"

    # Step 4: Select the first result image
    local select_result
    select_result=$($RODNEY_CMD js "
        (() => {
            // Try various selectors for image results in the modal
            const selectors = [
                // Wagtail image chooser result items
                '.modal.show .image-choice a',
                '.modal.show .listing-item a',
                '.modal.show .result-item a',
                '.modal.show [data-chooser-modal-choice]',
                // Generic modal results
                '[role=\"dialog\"] .image-choice a',
                '[role=\"dialog\"] .listing-item a',
                '[role=\"dialog\"] [data-chooser-modal-choice]',
                '.w-dialog .image-choice a',
                '.w-dialog .listing-item a',
                // Wagtail 6.x specific
                '.chooser-modal .listing a',
                '.chooser-modal button[data-chooser-modal-choice]',
                // Image thumbnails in results
                '.modal.show img[data-chooser-modal-choice]',
                '.modal.show .image-choice',
                '[role=\"dialog\"] .image-choice'
            ];

            for (const sel of selectors) {
                const el = document.querySelector(sel);
                if (el) {
                    el.click();
                    return 'selected';
                }
            }

            // Last resort: look for any clickable image in a modal
            const images = document.querySelectorAll(
                '.modal.show img, [role=\"dialog\"] img, .w-dialog img'
            );
            for (const img of images) {
                const parent = img.closest('a, button, [role=\"button\"]');
                if (parent) {
                    parent.click();
                    return 'selected-via-img';
                }
            }

            return 'no-results';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$select_result" == "selected" ]] || [[ "$select_result" == "selected-via-img" ]]; then
        sleep 2
        $RODNEY_CMD waitstable
        echo "  Image selected (${select_result}) for field '${field_name}'."
        take_named_screenshot "image-chosen-${field_name}"
        return 0
    fi

    echo "  [warn] Could not select image from search results: ${select_result}" >&2
    take_named_screenshot "error-no-image-results"

    # Close the modal so we don't block further operations
    _close_image_chooser_modal
    return 1
}

# Close any open image chooser modal (cleanup on failure)
_close_image_chooser_modal() {
    $RODNEY_CMD js "
        (() => {
            // Press Escape
            document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));

            // Also try clicking close buttons
            const closeBtn = document.querySelector(
                '.modal.show .close, ' +
                '.modal.show [data-dismiss=\"modal\"], ' +
                '[role=\"dialog\"] button[aria-label=\"Close\"], ' +
                '.w-dialog button[aria-label=\"Close\"]'
            );
            if (closeBtn) closeBtn.click();
            return 'closed';
        })()
    " 2>/dev/null || true
    sleep 1
    $RODNEY_CMD waitstable
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

            // Check for a contentpath field with the given name
            const field = block.querySelector('[data-contentpath=\"${field_name}\"]');
            if (!field) return 'no';

            // Verify it's an image chooser (has chooser button or image widget)
            const isImageChooser = field.querySelector(
                'button[data-chooser-url*=\"image\"], ' +
                '.image-chooser, ' +
                '[id*=\"image\"][id*=\"chooser\"], ' +
                '.chooser__choose-button, ' +
                '[data-chooser-action-choose]'
            );
            return isImageChooser ? 'yes' : 'no';
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
                // Skip if this is a nested block's contentpath (UUID-like)
                if (cp && cp.length < 40) {
                    const hasDraftail = !!f.querySelector('.Draftail-Editor');
                    const hasInput = !!f.querySelector('input:not([type=hidden])');
                    const hasTextarea = !!f.querySelector('textarea');
                    const hasChooser = !!f.querySelector('[data-chooser-action-choose], .chooser__choose-button, button[data-chooser-url]');
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
