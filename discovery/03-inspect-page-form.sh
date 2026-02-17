#!/usr/bin/env bash
# discovery/03-inspect-page-form.sh -- Inspect the page creation form fields
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Discovery Step 3: Inspect Page Form ==="

# Go directly to the create form
navigate_to_create_page "$PARENT_PAGE_ID" "$PAGE_TYPE_APP_LABEL" "$PAGE_TYPE_MODEL"
take_named_screenshot "discovery-03-create-form"

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
        // Look for data-contentpath elements that contain StreamField markers
        const containers = document.querySelectorAll('[data-streamfield], [data-contentpath]');
        const streamfields = [];
        containers.forEach(c => {
            const cp = c.dataset.contentpath || '';
            const hasAdd = c.querySelector('button[title*=\"Add\"], button[title*=\"Insert\"], .c-sf-add-button');
            if (cp && hasAdd) {
                streamfields.push('StreamField: ' + cp);
            }
        });

        // Also check for known StreamField class patterns
        const sfWidgets = document.querySelectorAll('[data-streamfield-block], .c-sf-container');
        sfWidgets.forEach(w => {
            const cp = w.closest('[data-contentpath]')?.dataset.contentpath || 'unknown';
            streamfields.push('StreamField widget in: ' + cp);
        });

        return streamfields.length > 0 ? streamfields.join('\\n') : 'No StreamFields detected (try inspecting manually)';
    })()
"
echo "------------------------------"

echo ""
echo "=== Discovery Step 3 complete ==="
