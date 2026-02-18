#!/usr/bin/env bash
# discovery/06-inspect-block-fields.sh -- Inspect block types for image and rich fields
# Adds each block type of interest, inspects its fields, and removes it.
# This helps us understand which blocks have image choosers, select fields, etc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/image-helpers.sh"

echo "=== Discovery Step 6: Inspect Block Fields (Image, Text-with-Image) ==="

# Ensure we're on the edit form
if ! element_exists "$SEL_EDIT_FORM" 2>/dev/null; then
    echo "  Navigating to edit form..."
    source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"
    navigate_to_edit_page "$TARGET_PAGE_ID"
fi

# Helper: add a block, inspect its fields, then remove it
inspect_block_type() {
    local block_type="$1"
    echo ""
    echo "--- Inspecting block type: ${block_type} ---"

    # Try to add the block
    if ! streamfield_add_block "body" "$block_type" 2>/dev/null; then
        echo "  Block type '${block_type}' not available in chooser."
        return 1
    fi

    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    # List all fields
    local fields
    fields=$(list_block_fields "$block_sel" 2>/dev/null || echo "[]")
    echo "  Fields: ${fields}"

    # Also do a deeper inspection via JS for any chooser widgets
    local detail
    detail=$($RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_sel}');
            if (!block) return JSON.stringify({error: 'no-block'});

            const info = { type: '${block_type}', fields: [] };
            const subfields = block.querySelectorAll('[data-contentpath]');

            subfields.forEach(f => {
                const cp = f.getAttribute('data-contentpath');
                if (!cp || cp.length > 40) return;  // skip UUID contentpaths

                const fieldInfo = { name: cp };

                // Detect field type
                if (f.querySelector('.Draftail-Editor')) {
                    fieldInfo.type = 'richtext (Draftail)';
                } else if (f.querySelector('button[data-chooser-url*=\"image\"], .chooser__choose-button, [data-chooser-action-choose]')) {
                    fieldInfo.type = 'image_chooser';
                    // Get the chooser URL for more detail
                    const btn = f.querySelector('button[data-chooser-url]');
                    if (btn) fieldInfo.chooser_url = btn.getAttribute('data-chooser-url');
                } else if (f.querySelector('select')) {
                    const sel = f.querySelector('select');
                    fieldInfo.type = 'select';
                    fieldInfo.options = Array.from(sel.options).map(o => ({value: o.value, label: o.textContent.trim()}));
                } else if (f.querySelector('input[type=\"url\"]')) {
                    fieldInfo.type = 'url';
                } else if (f.querySelector('input[type=\"number\"]')) {
                    fieldInfo.type = 'number';
                } else if (f.querySelector('textarea')) {
                    fieldInfo.type = 'textarea';
                } else if (f.querySelector('input:not([type=hidden])')) {
                    const inp = f.querySelector('input:not([type=hidden])');
                    fieldInfo.type = 'input:' + (inp.type || 'text');
                } else {
                    fieldInfo.type = 'unknown';
                }

                // Get any label
                const label = f.querySelector('label, .w-field__label');
                if (label) fieldInfo.label = label.textContent.trim();

                info.fields.push(fieldInfo);
            });

            return JSON.stringify(info, null, 2);
        })()
    " 2>/dev/null || echo "{}")

    echo "  Detail: ${detail}"
    take_named_screenshot "discovery-06-${block_type// /-}"

    # Remove the block we just added (mark as deleted)
    $RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_sel}');
            if (!block) return 'no-block';
            const delInput = block.querySelector('input[name*=\"-deleted\"]');
            if (delInput) {
                delInput.value = '1';
                block.style.display = 'none';
                return 'deleted';
            }
            return 'no-delete-input';
        })()
    " 2>/dev/null || true

    echo "  (Block removed after inspection)"
    echo "-----------------------------------"
    return 0
}

# Inspect the block types we care about for enhanced layouts

echo ""
echo "=== Inspecting Quote block ==="
inspect_block_type "Quote"

echo ""
echo "=== Inspecting Text-with-image variants ==="
# Try several possible names for this block type
for name in "Text with image" "Image with text" "Text and image" "Text + Image"; do
    if inspect_block_type "$name"; then
        echo "  Found text-with-image block as: '${name}'"
        break
    fi
done

echo ""
echo "=== Inspecting other potentially useful block types ==="
# Also check for other rich block types we might use
for name in "Image" "Gallery" "Full width image" "Card" "Feature"; do
    inspect_block_type "$name" || true
done

echo ""
echo "=== Discovery Step 6 complete ==="
echo ""
echo "Next steps:"
echo "  - Review the field details above to confirm block structures"
echo "  - Check screenshots in ${SCREENSHOT_DIR}/discovery-06-*"
echo "  - Update data/design-strategy-mba.json with image search terms"
echo "  - Run the update pipeline: bash update/run-all.sh"
