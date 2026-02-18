#!/usr/bin/env bash
# discovery/04-inspect-streamfield.sh -- Inspect EXISTING StreamField blocks on the page
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Discovery Step 4: Inspect Existing StreamField Blocks ==="

# Ensure we're on the edit form
if ! element_exists "$SEL_EDIT_FORM" 2>/dev/null; then
    echo "  Navigating to edit form..."
    navigate_to_edit_page "$TARGET_PAGE_ID"
fi

# Count existing blocks in the body StreamField
echo ""
echo "--- Block Count ---"
BLOCK_COUNT=$($RODNEY_CMD js "
    document.querySelector('[data-contentpath=\"body\"]')?.querySelector('input[data-streamfield-stream-count]')?.value || '0'
" 2>/dev/null || echo "0")
echo "  Body StreamField block count: $BLOCK_COUNT"
echo "--------------------"

# Enumerate all existing blocks with their types and content preview
echo ""
echo "--- Existing Blocks ---"
$RODNEY_CMD js "
    (() => {
        const container = document.querySelector('[data-contentpath=\"body\"]');
        if (!container) return 'No body StreamField container found!';

        const streamContainer = container.querySelector('[data-streamfield-stream-container]');
        if (!streamContainer) return 'No stream container found within body!';

        const blocks = streamContainer.querySelectorAll(':scope > [data-contentpath]');
        if (blocks.length === 0) return 'No blocks found in body StreamField.';

        const result = [];
        blocks.forEach((block, index) => {
            const contentpath = block.getAttribute('data-contentpath');

            // Try to determine block type from various indicators
            const typeInput = block.querySelector('input[name\$=\"-type\"]');
            const typeFromInput = typeInput ? typeInput.value : '';

            // Check for block type label
            const typeLabel = block.querySelector('.w-field__label, .c-sf-block__type, [data-block-type]');
            const typeFromLabel = typeLabel ? typeLabel.textContent.trim() : '';

            // Get the type from the block's header/controls
            const header = block.querySelector('.c-sf-block__header, .w-panel__header, [class*=\"block-header\"]');
            const typeFromHeader = header ? header.textContent.trim().split('\\n')[0].trim() : '';

            // Try to get content preview
            const textInput = block.querySelector('input[name\$=\"-value\"]:not([type=hidden])');
            const draftailEditor = block.querySelector('.public-DraftEditor-content, .Draftail-Editor');
            const hiddenInput = block.querySelector('input[type=hidden][name\$=\"-value\"]');

            let contentPreview = '';
            if (textInput) {
                contentPreview = textInput.value.substring(0, 100);
            } else if (draftailEditor) {
                contentPreview = draftailEditor.textContent.substring(0, 100);
            } else if (hiddenInput) {
                contentPreview = hiddenInput.value.substring(0, 100);
            }

            // Check for sub-fields (StructBlock)
            const subFields = block.querySelectorAll(':scope > [data-contentpath] [data-contentpath]');
            const subFieldNames = [];
            subFields.forEach(sf => {
                subFieldNames.push(sf.getAttribute('data-contentpath'));
            });

            result.push({
                index: index,
                contentpath: contentpath,
                type: typeFromInput || typeFromLabel || typeFromHeader || 'unknown',
                contentPreview: contentPreview,
                subFields: subFieldNames.length > 0 ? subFieldNames : undefined
            });
        });
        return JSON.stringify(result, null, 2);
    })()
"
echo "------------------------"

# Also look for available block types (what can be added)
echo ""
echo "--- Available Block Types (from add button) ---"
ADD_BTN_RESULT=$($RODNEY_CMD js "
    (() => {
        const container = document.querySelector('[data-contentpath=\"body\"]');
        if (!container) return 'no-container';
        const btns = container.querySelectorAll('.c-sf-add-button');
        if (!btns.length) return 'no-button';
        btns[btns.length - 1].click();
        return 'clicked';
    })()
" 2>/dev/null || echo "error")

if [[ "$ADD_BTN_RESULT" == "clicked" ]]; then
    sleep 1
    $RODNEY_CMD waitstable
    take_named_screenshot "discovery-04-block-chooser"

    $RODNEY_CMD js "
        (() => {
            // Check w-combobox options (Wagtail 6.x)
            const options = document.querySelectorAll('.w-combobox__option');
            if (options.length > 0) {
                const types = [];
                options.forEach(opt => {
                    const text = opt.querySelector('.w-combobox__option-text');
                    types.push(text ? text.textContent.trim() : opt.textContent.trim());
                });
                return 'Available block types: ' + types.join(', ');
            }

            // Check tippy buttons
            const tippyBtns = document.querySelectorAll('.tippy-content button');
            if (tippyBtns.length > 0) {
                const types = [];
                tippyBtns.forEach(btn => types.push(btn.textContent.trim()));
                return 'Available block types: ' + types.join(', ');
            }

            return 'Could not read block type options.';
        })()
    "

    # Close the chooser
    $RODNEY_CMD js "document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))" 2>/dev/null
    $RODNEY_CMD waitstable
else
    echo "  Could not open block chooser: $ADD_BTN_RESULT"
fi
echo "------------------------------------------------"

# Detailed inspection of each existing block's structure
echo ""
echo "--- Detailed Block Structure ---"
$RODNEY_CMD js "
    (() => {
        const container = document.querySelector('[data-contentpath=\"body\"]');
        if (!container) return 'No body container';

        const streamContainer = container.querySelector('[data-streamfield-stream-container]');
        if (!streamContainer) return 'No stream container';

        const blocks = streamContainer.querySelectorAll(':scope > [data-contentpath]');
        const details = [];

        blocks.forEach((block, index) => {
            const cp = block.getAttribute('data-contentpath');

            // Collect all inputs within this block
            const inputs = block.querySelectorAll('input, textarea, select');
            const inputDetails = [];
            inputs.forEach(inp => {
                if (inp.type === 'hidden' && !inp.name) return;
                inputDetails.push({
                    tag: inp.tagName.toLowerCase(),
                    type: inp.type || '',
                    name: inp.name || '',
                    id: inp.id || '',
                    value: (inp.value || '').substring(0, 200)
                });
            });

            // Check for Draftail editors
            const draftailEditors = block.querySelectorAll('.Draftail-Editor, .public-DraftEditor-content');
            const draftailCount = draftailEditors.length;

            details.push({
                index: index,
                contentpath: cp,
                inputCount: inputDetails.length,
                inputs: inputDetails,
                hasDraftail: draftailCount > 0,
                draftailCount: draftailCount
            });
        });

        return JSON.stringify(details, null, 2);
    })()
"
echo "--------------------------------"

take_named_screenshot "discovery-04-existing-blocks"

echo ""
echo "=== Discovery Step 4 complete ==="
