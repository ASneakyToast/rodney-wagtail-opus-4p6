#!/usr/bin/env bash
# lib/streamfield.sh -- StreamField block interaction helpers for Wagtail 6.x
# Source after config/env.sh, config/selectors.sh, and lib/rodney-helpers.sh

# Add a new block to a StreamField
# Usage: streamfield_add_block "body" "section_block"
streamfield_add_block() {
    local field_contentpath="$1"
    local block_type="$2"
    local container="[data-contentpath=\"${field_contentpath}\"]"

    echo "  Adding StreamField block: ${block_type} to ${field_contentpath}..."

    # Find and click the add-block button. Wagtail 6.x uses several patterns:
    # 1. A "+" button with data-streamfield-block-* attributes
    # 2. A button within the StreamField container

    # Try the most common pattern: the last "+" button in the container (appends)
    local add_btn_selector="${container} [data-streamfield-block-count] + button"

    # Fallback: try generic "add block" button patterns
    if ! element_exists "$add_btn_selector"; then
        add_btn_selector="${container} button[title*='Add']"
    fi
    if ! element_exists "$add_btn_selector"; then
        add_btn_selector="${container} button[title*='Insert']"
    fi
    if ! element_exists "$add_btn_selector"; then
        add_btn_selector="${container} button.c-sf-add-button"
    fi
    if ! element_exists "$add_btn_selector"; then
        # Last resort: use discovered selector from config
        if [[ -n "${SEL_ADD_BLOCK_BUTTON:-}" ]]; then
            add_btn_selector="${container} ${SEL_ADD_BLOCK_BUTTON}"
        else
            echo "  [error] Cannot find add-block button in ${container}" >&2
            take_named_screenshot "error-no-add-block-btn"
            return 1
        fi
    fi

    rodney_wait_and_click "$add_btn_selector"
    $RODNEY_CMD waitstable

    # Now select the block type from the chooser.
    # Wagtail 6.x uses a Tippy.js popover or inline buttons.
    local block_btn=""

    # Pattern 1: button with data-block-type attribute
    block_btn="button[data-block-type=\"${block_type}\"]"
    if element_exists "$block_btn"; then
        rodney_cmd click "$block_btn"
        $RODNEY_CMD waitstable
        echo "  Block '${block_type}' added."
        return 0
    fi

    # Pattern 2: button inside .tippy-content
    block_btn=".tippy-content button[data-block-type=\"${block_type}\"]"
    if element_exists "$block_btn"; then
        rodney_cmd click "$block_btn"
        $RODNEY_CMD waitstable
        echo "  Block '${block_type}' added."
        return 0
    fi

    # Pattern 3: button with text matching the block type
    local found
    found=$($RODNEY_CMD js "
        const btns = document.querySelectorAll('.tippy-content button, [data-contentpath=\"${field_contentpath}\"] button');
        const match = Array.from(btns).find(b => b.textContent.trim().toLowerCase().includes('${block_type}'.replace('_', ' ')));
        match ? 'found' : 'notfound';
    " 2>/dev/null || echo "notfound")

    if [[ "$found" == "found" ]]; then
        $RODNEY_CMD js "
            const btns = document.querySelectorAll('.tippy-content button, [data-contentpath=\"${field_contentpath}\"] button');
            const match = Array.from(btns).find(b => b.textContent.trim().toLowerCase().includes('${block_type}'.replace('_', ' ')));
            if (match) match.click();
        "
        $RODNEY_CMD waitstable
        echo "  Block '${block_type}' added (text match)."
        return 0
    fi

    # Pattern 4: use discovered chooser selector
    if [[ -n "${SEL_BLOCK_CHOOSER:-}" ]]; then
        block_btn="${SEL_BLOCK_CHOOSER} button[data-block-type=\"${block_type}\"]"
        if element_exists "$block_btn"; then
            rodney_cmd click "$block_btn"
            $RODNEY_CMD waitstable
            echo "  Block '${block_type}' added (discovered chooser)."
            return 0
        fi
    fi

    echo "  [error] Could not find block type '${block_type}' in chooser." >&2
    take_named_screenshot "error-block-type-not-found"
    return 1
}

# Count blocks currently in a StreamField
streamfield_count_blocks() {
    local field_contentpath="$1"
    $RODNEY_CMD js "
        document.querySelectorAll('[data-contentpath=\"${field_contentpath}\"] [data-streamfield-block]').length
    " 2>/dev/null || echo "0"
}

# Get a CSS selector for the last (most recently added) block in a StreamField
streamfield_get_last_block() {
    local field_contentpath="$1"
    local count
    count=$(streamfield_count_blocks "$field_contentpath")

    if [[ "$count" == "0" ]]; then
        echo "[data-contentpath=\"${field_contentpath}\"]"
    else
        echo "[data-contentpath=\"${field_contentpath}\"] [data-streamfield-block]:last-child"
    fi
}

# Fill a sub-field within a StreamField block
# Usage: streamfield_fill_field "body" "headline" "Some headline text"
streamfield_fill_field() {
    local parent_selector="$1"
    local field_name="$2"
    local value="$3"

    local selector="${parent_selector} [data-contentpath=\"${field_name}\"] input"

    # Try input first, then textarea
    if ! element_exists "$selector"; then
        selector="${parent_selector} [data-contentpath=\"${field_name}\"] textarea"
    fi

    if element_exists "$selector"; then
        rodney_safe_input "$selector" "$value"
    else
        echo "  [warn] Field '${field_name}' not found in block." >&2
    fi
}
