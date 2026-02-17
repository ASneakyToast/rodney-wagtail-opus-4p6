#!/usr/bin/env bash
# discovery/04-inspect-streamfield.sh -- Inspect StreamField block types and sub-fields
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

echo "=== Discovery Step 4: Inspect StreamField Blocks ==="

# We should already be on the create-page form from step 3.
# If not, navigate there.
if ! element_exists "$SEL_EDIT_FORM"; then
    echo "  Navigating to create form..."
    rodney_cmd open "${WAGTAIL_ADMIN_URL}/pages/${PARENT_PAGE_ID}/add/${PAGE_TYPE_APP_LABEL}/${PAGE_TYPE_MODEL}/"
    wait_for_page
fi

# Find all add-block buttons and try to open the block chooser
echo ""
echo "--- Searching for Add Block Buttons ---"
$RODNEY_CMD js "
    (() => {
        const buttons = document.querySelectorAll(
            'button[title*=\"Add\"], button[title*=\"Insert\"], ' +
            'button[data-streamfield-block-count], .c-sf-add-button, ' +
            'button[class*=\"stream\"], [data-contentpath] button'
        );
        const result = [];
        buttons.forEach(btn => {
            const cp = btn.closest('[data-contentpath]')?.dataset.contentpath || 'root';
            result.push({
                text: btn.textContent.trim().substring(0, 50),
                title: btn.title || '',
                class: btn.className.substring(0, 80),
                parentContentpath: cp,
                selector: btn.id ? '#' + btn.id : ''
            });
        });
        return JSON.stringify(result, null, 2);
    })()
"

# Try clicking the first add-block button to reveal block types
echo ""
echo "--- Attempting to Open Block Chooser ---"
ADD_BTN_RESULT=$($RODNEY_CMD js "
    (() => {
        // Find a likely add-block button
        const candidates = [
            ...document.querySelectorAll('button[title*=\"Add\"]'),
            ...document.querySelectorAll('button[title*=\"Insert\"]'),
            ...document.querySelectorAll('.c-sf-add-button'),
        ];
        if (candidates.length > 0) {
            candidates[0].click();
            return 'clicked: ' + (candidates[0].title || candidates[0].textContent.trim());
        }
        return 'no-button-found';
    })()
" 2>/dev/null || echo "error")

echo "  Result: $ADD_BTN_RESULT"

if [[ "$ADD_BTN_RESULT" != "no-button-found" ]] && [[ "$ADD_BTN_RESULT" != "error" ]]; then
    $RODNEY_CMD waitstable
    take_named_screenshot "discovery-04-block-chooser"

    # Extract block types from the chooser
    echo ""
    echo "--- Available Block Types ---"
    $RODNEY_CMD js "
        (() => {
            // Check Tippy.js popovers
            const tippyBtns = document.querySelectorAll('.tippy-content button');
            if (tippyBtns.length > 0) {
                const types = [];
                tippyBtns.forEach(btn => {
                    types.push({
                        text: btn.textContent.trim(),
                        blockType: btn.dataset.blockType || '',
                        class: btn.className.substring(0, 60)
                    });
                });
                return 'Source: tippy-content\\n' + JSON.stringify(types, null, 2);
            }

            // Check for inline block type buttons
            const blockBtns = document.querySelectorAll('button[data-block-type]');
            if (blockBtns.length > 0) {
                const types = [];
                blockBtns.forEach(btn => {
                    types.push({
                        text: btn.textContent.trim(),
                        blockType: btn.dataset.blockType
                    });
                });
                return 'Source: data-block-type\\n' + JSON.stringify(types, null, 2);
            }

            // Check for any newly appeared modal/dropdown
            const menus = document.querySelectorAll('[role=\"menu\"], [role=\"listbox\"], .dropdown-menu');
            if (menus.length > 0) {
                const items = [];
                menus.forEach(menu => {
                    menu.querySelectorAll('button, a').forEach(item => {
                        items.push(item.textContent.trim());
                    });
                });
                return 'Source: menu/dropdown\\n' + items.join('\\n');
            }

            return 'No block type chooser detected.';
        })()
    "
    echo "----------------------------"

    # Close the chooser by pressing Escape
    $RODNEY_CMD js "document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))"
    $RODNEY_CMD waitstable

    # Try adding one block to inspect its sub-fields
    echo ""
    echo "--- Inspecting Block Sub-Fields ---"
    echo "(Adding first available block type to inspect its structure)"

    ADDED=$($RODNEY_CMD js "
        (() => {
            // Re-open chooser
            const addBtns = [
                ...document.querySelectorAll('button[title*=\"Add\"]'),
                ...document.querySelectorAll('.c-sf-add-button'),
            ];
            if (addBtns.length > 0) addBtns[0].click();
            return 'reopened';
        })()
    " 2>/dev/null || echo "error")

    sleep 1
    $RODNEY_CMD waitstable

    # Click the first block type
    $RODNEY_CMD js "
        (() => {
            const btns = document.querySelectorAll('.tippy-content button, button[data-block-type]');
            if (btns.length > 0) {
                btns[0].click();
                return 'added: ' + btns[0].textContent.trim();
            }
            return 'no blocks to add';
        })()
    "

    sleep 1
    $RODNEY_CMD waitstable
    take_named_screenshot "discovery-04-block-added"

    # Inspect the sub-fields of the new block
    echo ""
    echo "--- New Block Sub-Fields ---"
    $RODNEY_CMD js "
        (() => {
            const blocks = document.querySelectorAll('[data-streamfield-block]');
            if (blocks.length === 0) return 'No blocks found after adding.';

            const lastBlock = blocks[blocks.length - 1];
            const fields = [];
            lastBlock.querySelectorAll('[data-contentpath]').forEach(field => {
                const cp = field.dataset.contentpath;
                const input = field.querySelector('input, textarea, select');
                const hasDraftail = field.querySelector('.Draftail-Editor, [contenteditable]') !== null;
                const hasChooser = field.querySelector('[data-chooser-url], .chooser') !== null;

                fields.push({
                    contentpath: cp,
                    inputType: input ? input.type : (hasDraftail ? 'draftail' : (hasChooser ? 'chooser' : 'unknown')),
                    inputId: input?.id || '',
                    hasDraftail: hasDraftail,
                    hasChooser: hasChooser
                });
            });

            return JSON.stringify(fields, null, 2);
        })()
    "
    echo "----------------------------"
fi

echo ""
echo "=== Discovery Step 4 complete ==="
