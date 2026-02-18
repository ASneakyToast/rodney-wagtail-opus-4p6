#!/usr/bin/env bash
# discovery/02-discover-page-types.sh -- Verify target page type and inspect metadata
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Discovery Step 2: Verify Target Page Type ==="

# Navigate to the target page's edit form to inspect its type
navigate_to_edit_page "$TARGET_PAGE_ID"
take_named_screenshot "discovery-02-target-edit"

# Try to detect the page type from the edit form URL or DOM
echo ""
echo "--- Page Type Detection ---"
$RODNEY_CMD js "
    (() => {
        const url = window.location.href;
        const result = { url: url };

        // Check for page type indicators in the form
        const form = document.querySelector('#page-edit-form');
        if (form) {
            result.formAction = form.action || '';
        }

        // Check breadcrumbs or header for page type info
        const breadcrumb = document.querySelector('.w-breadcrumbs, .breadcrumb, nav[aria-label=\"Breadcrumb\"]');
        if (breadcrumb) {
            result.breadcrumb = breadcrumb.textContent.trim().substring(0, 200);
        }

        // Check for page type in header
        const header = document.querySelector('.w-header, .content-wrapper header');
        if (header) {
            result.headerText = header.textContent.trim().substring(0, 200);
        }

        // Check for content_type hidden field (Wagtail stores this)
        const contentType = document.querySelector('input[name=\"content_type\"]');
        if (contentType) {
            result.contentType = contentType.value;
        }

        return JSON.stringify(result, null, 2);
    })()
"
echo "---------------------------"

# Also check what child page types are allowed (for reference)
echo ""
echo "--- Available Child Page Types (for reference) ---"
navigate_to_add_subpage "$TARGET_PAGE_ID"
take_named_screenshot "discovery-02-child-page-types"

$RODNEY_CMD js "
    (() => {
        const links = document.querySelectorAll('a[href*=\"/add/\"]');
        const types = [];
        links.forEach(link => {
            const href = link.getAttribute('href');
            const text = link.textContent.trim();
            const match = href.match(/\\/add\\/([^/]+)\\/([^/]+)\\//);
            if (match) {
                types.push(match[1] + '.' + match[2] + ' -> ' + text);
            }
        });
        return types.join('\\n') || 'No child page types found (or not on add_subpage screen)';
    })()
"
echo "---------------------------------------------------"

echo ""
echo "=== Discovery Step 2 complete ==="
