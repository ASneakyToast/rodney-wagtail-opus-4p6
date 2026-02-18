#!/usr/bin/env bash
# discovery/03-inspect-page-form.sh -- Inspect the existing page EDIT form
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Discovery Step 3: Inspect Page Edit Form ==="

# Navigate to the EDIT form of the target page
navigate_to_edit_page "$TARGET_PAGE_ID"
take_named_screenshot "discovery-03-edit-form"

# Capture the page title from the form
echo ""
echo "--- Page Title ---"
$RODNEY_CMD js "document.querySelector('#id_title')?.value || '(no title field)'" 2>/dev/null || echo "(error reading title)"
echo "------------------"

# Enumerate all form fields
echo ""
echo "--- Form Fields ---"
$RODNEY_CMD js "
    (() => {
        const form = document.querySelector('#page-edit-form') || document.querySelector('form');
        if (!form) return 'No form found!';

        const fields = [];
        const inputs = form.querySelectorAll('input, textarea, select');
        inputs.forEach(el => {
            if (el.type === 'hidden' && !el.id) return; // skip CSRF etc.
            fields.push({
                tag: el.tagName.toLowerCase(),
                type: el.type || '',
                id: el.id || '',
                name: el.name || '',
                value: (el.value || '').substring(0, 100),
                contentpath: el.closest('[data-contentpath]')?.dataset.contentpath || ''
            });
        });
        return JSON.stringify(fields, null, 2);
    })()
"
echo "--------------------"

# Find tabs in the form
echo ""
echo "--- Form Tabs ---"
$RODNEY_CMD js "
    (() => {
        const tabs = document.querySelectorAll('[role=\"tab\"], .tab-nav a, .w-tabs__tab');
        const result = [];
        tabs.forEach(tab => {
            result.push(tab.textContent.trim() + ' -> ' + (tab.getAttribute('href') || tab.dataset.tab || ''));
        });
        return result.join('\\n') || 'No tabs found';
    })()
"
echo "-----------------"

# Identify StreamField containers
echo ""
echo "--- StreamField Containers ---"
$RODNEY_CMD js "
    (() => {
        const containers = document.querySelectorAll('[data-streamfield], [data-contentpath]');
        const streamfields = [];
        containers.forEach(c => {
            const cp = c.dataset.contentpath || '';
            const hasAdd = c.querySelector('button[title*=\"Add\"], button[title*=\"Insert\"], .c-sf-add-button');
            if (cp && hasAdd) {
                streamfields.push('StreamField: ' + cp);
            }
        });

        const sfWidgets = document.querySelectorAll('[data-streamfield-block], .c-sf-container');
        sfWidgets.forEach(w => {
            const cp = w.closest('[data-contentpath]')?.dataset.contentpath || 'unknown';
            streamfields.push('StreamField widget in: ' + cp);
        });

        return streamfields.length > 0 ? streamfields.join('\\n') : 'No StreamFields detected';
    })()
"
echo "------------------------------"

# Look for display_template field specifically
echo ""
echo "--- Display Template Field ---"
$RODNEY_CMD js "
    (() => {
        // Search for display_template by id, name, or contentpath
        const byId = document.querySelector('#id_display_template');
        const byName = document.querySelector('[name=\"display_template\"]');
        const byContentpath = document.querySelector('[data-contentpath=\"display_template\"]');
        const el = byId || byName || byContentpath;

        if (!el) {
            // Search more broadly for any field with 'template' in its name/id
            const allInputs = document.querySelectorAll('input, select, textarea');
            const templateFields = [];
            allInputs.forEach(inp => {
                const id = inp.id || '';
                const name = inp.name || '';
                if (id.toLowerCase().includes('template') || name.toLowerCase().includes('template')) {
                    templateFields.push({
                        tag: inp.tagName.toLowerCase(),
                        type: inp.type || '',
                        id: id,
                        name: name,
                        value: inp.value || ''
                    });
                }
            });
            if (templateFields.length > 0) {
                return 'Found template-related fields:\\n' + JSON.stringify(templateFields, null, 2);
            }
            return 'No display_template field found on this tab. May be on Settings or another tab.';
        }

        const tag = el.tagName.toLowerCase();
        if (tag === 'select') {
            const options = [];
            el.querySelectorAll('option').forEach(opt => {
                options.push({ value: opt.value, text: opt.textContent.trim(), selected: opt.selected });
            });
            return JSON.stringify({ tag, id: el.id, name: el.name, currentValue: el.value, options }, null, 2);
        }

        return JSON.stringify({ tag, type: el.type, id: el.id, name: el.name, value: el.value }, null, 2);
    })()
"
echo "------------------------------"

# Check all tabs for display_template
echo ""
echo "--- Checking Settings Tab for Display Template ---"
SETTINGS_TAB='a[href="#tab-settings"]'
if element_exists "$SETTINGS_TAB" 2>/dev/null; then
    rodney_cmd click "$SETTINGS_TAB"
    $RODNEY_CMD waitstable
    take_named_screenshot "discovery-03-settings-tab"

    $RODNEY_CMD js "
        (() => {
            const allInputs = document.querySelectorAll('#tab-settings input, #tab-settings select, #tab-settings textarea');
            const fields = [];
            allInputs.forEach(inp => {
                fields.push({
                    tag: inp.tagName.toLowerCase(),
                    type: inp.type || '',
                    id: inp.id || '',
                    name: inp.name || '',
                    value: (inp.value || '').substring(0, 100)
                });
            });
            if (fields.length === 0) {
                // Broader search: visible panels
                const panels = document.querySelectorAll('[id*=\"settings\"], [class*=\"settings\"]');
                panels.forEach(p => {
                    p.querySelectorAll('input, select, textarea').forEach(inp => {
                        fields.push({
                            tag: inp.tagName.toLowerCase(),
                            type: inp.type || '',
                            id: inp.id || '',
                            name: inp.name || '',
                            value: (inp.value || '').substring(0, 100)
                        });
                    });
                });
            }
            return fields.length > 0 ? JSON.stringify(fields, null, 2) : 'No fields found in Settings tab';
        })()
    "

    # Switch back to Content tab
    if element_exists "$SEL_TAB_CONTENT" 2>/dev/null; then
        rodney_cmd click "$SEL_TAB_CONTENT"
        $RODNEY_CMD waitstable
    fi
else
    echo "  Settings tab not found."
fi
echo "---------------------------------------------------"

echo ""
echo "=== Discovery Step 3 complete ==="
