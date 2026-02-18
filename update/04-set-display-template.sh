#!/usr/bin/env bash
# update/04-set-display-template.sh -- Set the display template to "flexible template"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

echo "=== Update Step 4: Set Display Template ==="

# The display_template field might be on the Content tab or Settings tab.
# We'll search all tabs.

# First, try the Content tab (current view)
TEMPLATE_FOUND=$($RODNEY_CMD js "
    (() => {
        // Try multiple possible selectors for the display template field
        const candidates = [
            document.querySelector('#id_display_template'),
            document.querySelector('[name=\"display_template\"]'),
            document.querySelector('${SEL_DISPLAY_TEMPLATE:-#id_display_template}'),
        ];

        for (const el of candidates) {
            if (el) return JSON.stringify({
                found: true,
                tag: el.tagName.toLowerCase(),
                id: el.id,
                name: el.name,
                tab: 'content'
            });
        }

        // Search for any template-related select/input
        const allInputs = document.querySelectorAll('select, input');
        for (const inp of allInputs) {
            const id = (inp.id || '').toLowerCase();
            const name = (inp.name || '').toLowerCase();
            if (id.includes('template') || name.includes('template')) {
                return JSON.stringify({
                    found: true,
                    tag: inp.tagName.toLowerCase(),
                    id: inp.id,
                    name: inp.name,
                    tab: 'content'
                });
            }
        }

        return JSON.stringify({ found: false, tab: 'content' });
    })()
" 2>/dev/null || echo '{"found":false}')

echo "  Content tab search: $TEMPLATE_FOUND"

# Check if we found it
FOUND=$(echo "$TEMPLATE_FOUND" | jq -r '.found' 2>/dev/null || echo "false")

# If not found on Content tab, check Settings tab
if [[ "$FOUND" != "true" ]]; then
    echo "  Not found on Content tab. Checking Settings tab..."

    if element_exists 'a[href="#tab-settings"]' 2>/dev/null; then
        rodney_cmd click 'a[href="#tab-settings"]'
        $RODNEY_CMD waitstable

        TEMPLATE_FOUND=$($RODNEY_CMD js "
            (() => {
                const allInputs = document.querySelectorAll('select, input');
                for (const inp of allInputs) {
                    const id = (inp.id || '').toLowerCase();
                    const name = (inp.name || '').toLowerCase();
                    if (id.includes('template') || name.includes('template') || id.includes('display') || name.includes('display')) {
                        return JSON.stringify({
                            found: true,
                            tag: inp.tagName.toLowerCase(),
                            id: inp.id,
                            name: inp.name,
                            tab: 'settings'
                        });
                    }
                }
                return JSON.stringify({ found: false, tab: 'settings' });
            })()
        " 2>/dev/null || echo '{"found":false}')

        echo "  Settings tab search: $TEMPLATE_FOUND"
        FOUND=$(echo "$TEMPLATE_FOUND" | jq -r '.found' 2>/dev/null || echo "false")
    fi
fi

# If not found on Settings tab either, check Promote tab
if [[ "$FOUND" != "true" ]]; then
    echo "  Not found on Settings tab. Checking Promote tab..."

    if element_exists 'a[href="#tab-promote"]' 2>/dev/null; then
        rodney_cmd click 'a[href="#tab-promote"]'
        $RODNEY_CMD waitstable

        TEMPLATE_FOUND=$($RODNEY_CMD js "
            (() => {
                const allInputs = document.querySelectorAll('select, input');
                for (const inp of allInputs) {
                    const id = (inp.id || '').toLowerCase();
                    const name = (inp.name || '').toLowerCase();
                    if (id.includes('template') || name.includes('template') || id.includes('display') || name.includes('display')) {
                        return JSON.stringify({
                            found: true,
                            tag: inp.tagName.toLowerCase(),
                            id: inp.id,
                            name: inp.name,
                            tab: 'promote'
                        });
                    }
                }
                return JSON.stringify({ found: false, tab: 'promote' });
            })()
        " 2>/dev/null || echo '{"found":false}')

        echo "  Promote tab search: $TEMPLATE_FOUND"
        FOUND=$(echo "$TEMPLATE_FOUND" | jq -r '.found' 2>/dev/null || echo "false")
    fi
fi

# Now set the value if we found the field
if [[ "$FOUND" == "true" ]]; then
    FIELD_ID=$(echo "$TEMPLATE_FOUND" | jq -r '.id // empty' 2>/dev/null)
    FIELD_NAME=$(echo "$TEMPLATE_FOUND" | jq -r '.name // empty' 2>/dev/null)
    FIELD_TAG=$(echo "$TEMPLATE_FOUND" | jq -r '.tag // empty' 2>/dev/null)

    # Build selector
    local_sel=""
    if [[ -n "$FIELD_ID" ]]; then
        local_sel="#${FIELD_ID}"
    elif [[ -n "$FIELD_NAME" ]]; then
        local_sel="[name=\"${FIELD_NAME}\"]"
    fi

    if [[ -n "$local_sel" ]]; then
        echo "  Setting display template field (${local_sel}) to 'flexible template'..."

        if [[ "$FIELD_TAG" == "select" ]]; then
            # For select elements, find and select the "flexible" option
            RESULT=$($RODNEY_CMD js "
                (() => {
                    const sel = document.querySelector('${local_sel}');
                    if (!sel) return 'element-not-found';

                    // List all options
                    const options = Array.from(sel.options);
                    const optionTexts = options.map(o => o.text.trim() + ' (' + o.value + ')');

                    // Find 'flexible template' option (case-insensitive)
                    const match = options.find(o =>
                        o.text.toLowerCase().includes('flexible')
                    );

                    if (match) {
                        sel.value = match.value;
                        sel.dispatchEvent(new Event('change', { bubbles: true }));
                        return 'selected: ' + match.text + ' (value=' + match.value + ')';
                    }

                    return 'no-flexible-option. Available: ' + optionTexts.join(', ');
                })()
            " 2>/dev/null || echo "error")
            echo "  Result: $RESULT"
        else
            # For input elements, type the value
            rodney_safe_input "$local_sel" "flexible template"
        fi

        take_named_screenshot "update-04-display-template-set"
    fi
else
    echo "  [warn] Display template field not found on any tab."
    echo "  This field may not exist on this page type, or has a different name."
    echo "  Continuing with other updates..."
    take_named_screenshot "update-04-display-template-not-found"
fi

# Switch back to Content tab for next steps
if element_exists "$SEL_TAB_CONTENT" 2>/dev/null; then
    rodney_cmd click "$SEL_TAB_CONTENT"
    $RODNEY_CMD waitstable
fi

echo ""
echo "=== Update Step 4 complete ==="
