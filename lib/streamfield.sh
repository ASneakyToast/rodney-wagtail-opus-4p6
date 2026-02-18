#!/usr/bin/env bash
# lib/streamfield.sh -- StreamField block interaction helpers for Wagtail 6.x
# Source after config/env.sh, config/selectors.sh, and lib/rodney-helpers.sh

# =====================================================
# Functions for inspecting/updating EXISTING blocks
# =====================================================

# List all existing blocks in a StreamField, returning JSON array with type and contentpath
# Usage: streamfield_list_blocks "body"
streamfield_list_blocks() {
    local field_contentpath="$1"
    $RODNEY_CMD js "
        (() => {
            const container = document.querySelector('[data-contentpath=\"${field_contentpath}\"]');
            if (!container) return '[]';
            const sc = container.querySelector('[data-streamfield-stream-container]');
            if (!sc) return '[]';
            const blocks = sc.querySelectorAll(':scope > [data-contentpath]');
            const result = [];
            blocks.forEach((block, i) => {
                const typeInput = block.querySelector('input[name\$=\"-type\"]');
                result.push({
                    index: i,
                    contentpath: block.getAttribute('data-contentpath'),
                    type: typeInput ? typeInput.value : 'unknown'
                });
            });
            return JSON.stringify(result);
        })()
    " 2>/dev/null || echo "[]"
}

# Get CSS selector for a block by its index (0-based) within a StreamField
# Usage: streamfield_get_block_by_index "body" 0
streamfield_get_block_by_index() {
    local field_contentpath="$1"
    local index="$2"
    local uuid
    uuid=$($RODNEY_CMD js "
        (() => {
            const container = document.querySelector('[data-contentpath=\"${field_contentpath}\"]');
            if (!container) return '';
            const sc = container.querySelector('[data-streamfield-stream-container]');
            if (!sc) return '';
            const blocks = sc.querySelectorAll(':scope > [data-contentpath]');
            if (${index} >= blocks.length) return '';
            return blocks[${index}].getAttribute('data-contentpath');
        })()
    " 2>/dev/null || echo "")

    if [[ -z "$uuid" ]]; then
        echo "  [error] Block at index ${index} not found in ${field_contentpath}" >&2
        return 1
    fi

    echo "[data-contentpath=\"${uuid}\"]"
}

# Delete a block by its selector (clicks the delete button within the block)
# Usage: streamfield_delete_block "$block_selector"
streamfield_delete_block() {
    local block_selector="$1"
    $RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_selector}');
            if (!block) return 'not-found';
            const delBtn = block.querySelector('button[title=\"Delete\"], button[aria-label=\"Delete\"]');
            if (delBtn) { delBtn.click(); return 'deleted'; }
            return 'no-delete-btn';
        })()
    " 2>/dev/null || echo "error"
    sleep 0.5
    $RODNEY_CMD waitstable
}

# Delete ALL blocks in a StreamField (clears the field for fresh content)
# Usage: streamfield_clear_all_blocks "body"
streamfield_clear_all_blocks() {
    local field_contentpath="$1"
    local count
    count=$(streamfield_count_blocks "$field_contentpath")
    echo "  Clearing ${count} existing blocks from ${field_contentpath}..."

    # Delete from last to first to avoid index shifting
    while [[ "$count" -gt 0 ]]; do
        local block_sel
        block_sel=$(streamfield_get_last_block "$field_contentpath" 2>/dev/null) || break
        streamfield_delete_block "$block_sel"
        count=$(streamfield_count_blocks "$field_contentpath")
    done
    echo "  Cleared. Remaining blocks: $(streamfield_count_blocks "$field_contentpath")"
}

# =====================================================
# Functions for adding NEW blocks (original)
# =====================================================

# Add a new block to a StreamField (appended at the end)
# Usage: streamfield_add_block "body" "Paragraph"
# Block type name must match the display text in the block chooser combobox.
streamfield_add_block() {
    local field_contentpath="$1"
    local block_type="$2"

    echo "  Adding StreamField block: ${block_type} to ${field_contentpath}..."

    # Click the LAST add-block button to append (buttons are interspersed between blocks)
    local clicked
    clicked=$($RODNEY_CMD js "
        (() => {
            const container = document.querySelector('[data-contentpath=\"${field_contentpath}\"]');
            if (!container) return 'no-container';
            const btns = container.querySelectorAll('.c-sf-add-button');
            if (!btns.length) return 'no-button';
            btns[btns.length - 1].click();
            return 'clicked';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$clicked" != "clicked" ]]; then
        echo "  [error] Cannot click add-block button: ${clicked}" >&2
        take_named_screenshot "error-no-add-block-btn"
        return 1
    fi

    sleep 1
    $RODNEY_CMD waitstable

    # Wagtail 6.x uses a combobox (w-combobox) for block selection.
    # Select the block type by matching option text.
    local selected
    selected=$($RODNEY_CMD js "
        (() => {
            const options = document.querySelectorAll('.w-combobox__option');
            for (const opt of options) {
                const text = opt.querySelector('.w-combobox__option-text');
                if (text && text.textContent.trim() === '${block_type}') {
                    opt.click();
                    return 'selected';
                }
            }
            return 'not_found';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$selected" == "selected" ]]; then
        sleep 1
        $RODNEY_CMD waitstable
        echo "  Block '${block_type}' added."
        return 0
    fi

    echo "  [error] Could not find block type '${block_type}' in chooser." >&2
    take_named_screenshot "error-block-type-not-found"
    return 1
}

# Count blocks currently in a StreamField
streamfield_count_blocks() {
    local field_contentpath="$1"
    $RODNEY_CMD js "
        document.querySelector('[data-contentpath=\"${field_contentpath}\"]')?.querySelector('input[data-streamfield-stream-count]')?.value || '0'
    " 2>/dev/null || echo "0"
}

# Get a CSS selector for the last (most recently added) block in a StreamField.
# Returns a selector using the block's UUID contentpath.
streamfield_get_last_block() {
    local field_contentpath="$1"
    local uuid
    uuid=$($RODNEY_CMD js "
        (() => {
            const blocks = document.querySelectorAll('[data-contentpath=\"${field_contentpath}\"] [data-streamfield-stream-container] > [data-contentpath]');
            return blocks.length ? blocks[blocks.length - 1].getAttribute('data-contentpath') : '';
        })()
    " 2>/dev/null || echo "")

    if [[ -z "$uuid" ]]; then
        echo "  [error] No blocks found in ${field_contentpath}" >&2
        return 1
    fi

    echo "[data-contentpath=\"${uuid}\"]"
}

# Fill the primary value input of a simple (CharBlock) StreamField block.
# For blocks like Heading that have a single text input named "body-N-value".
streamfield_fill_value() {
    local block_selector="$1"
    local value="$2"

    local selector="${block_selector} input[name\$='-value']:not([type=hidden])"
    if element_exists "$selector"; then
        rodney_safe_input "$selector" "$value"
    else
        echo "  [warn] Value input not found in block ${block_selector}" >&2
    fi
}

# Fill a sub-field within a StructBlock
# Usage: streamfield_fill_field "$block_selector" "headline" "Some text"
streamfield_fill_field() {
    local parent_selector="$1"
    local field_name="$2"
    local value="$3"

    # Try data-contentpath first (StructBlock sub-fields)
    local selector="${parent_selector} [data-contentpath=\"${field_name}\"] input:not([type=hidden])"
    if element_exists "$selector"; then
        rodney_safe_input "$selector" "$value"
        return
    fi

    # Try textarea
    selector="${parent_selector} [data-contentpath=\"${field_name}\"] textarea"
    if element_exists "$selector"; then
        rodney_safe_input "$selector" "$value"
        return
    fi

    # Try name-based matching (body-N-value-fieldname pattern)
    selector="${parent_selector} input[name\$='-${field_name}']:not([type=hidden])"
    if element_exists "$selector"; then
        rodney_safe_input "$selector" "$value"
        return
    fi

    echo "  [warn] Field '${field_name}' not found in block." >&2
}

# Fill a Draftail (rich text) editor within a StreamField block
# For RichTextBlocks (e.g., Paragraph), the editor is directly in the block.
# For StructBlock sub-fields, specify the field name.
streamfield_fill_draftail() {
    local parent_selector="$1"
    local field_name="$2"
    local text="$3"

    local draftail_selector
    if [[ -n "$field_name" ]]; then
        draftail_selector="${parent_selector} [data-contentpath=\"${field_name}\"]"
    else
        draftail_selector="${parent_selector}"
    fi

    # Use draftail_set_content if available
    if declare -f draftail_set_content &>/dev/null; then
        draftail_set_content "$draftail_selector" "$text"
    else
        # Fallback: click the editor and type
        local editor="${draftail_selector} .public-DraftEditor-content"
        if element_exists "$editor"; then
            $RODNEY_CMD click "$editor"
            sleep 0.5
            $RODNEY_CMD input "$editor" "$text"
        else
            echo "  [warn] Draftail editor not found at ${draftail_selector}" >&2
        fi
    fi
}
