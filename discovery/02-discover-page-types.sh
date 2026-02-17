#!/usr/bin/env bash
# discovery/02-discover-page-types.sh -- Discover available page types under parent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/wagtail-navigation.sh"

echo "=== Discovery Step 2: Discover Page Types ==="

navigate_to_add_subpage "$PARENT_PAGE_ID"
take_named_screenshot "discovery-02-page-type-chooser"

# Extract all page type links from the chooser page
echo ""
echo "--- Available Page Types ---"
$RODNEY_CMD js "
    (() => {
        // Wagtail 6.x page type chooser: links with href containing /add/
        const links = document.querySelectorAll('a[href*=\"/add/\"]');
        const types = [];
        links.forEach(link => {
            const href = link.getAttribute('href');
            const text = link.textContent.trim();
            // Extract app_label and model from URL pattern: /pages/ID/add/APP/MODEL/
            const match = href.match(/\\/add\\/([^/]+)\\/([^/]+)\\//);
            if (match) {
                types.push(match[1] + '.' + match[2] + ' -> ' + text);
            }
        });
        return types.join('\\n') || 'No page types found';
    })()
"
echo "----------------------------"

# Check if the configured page type exists
echo ""
echo "  Looking for configured type: ${PAGE_TYPE_APP_LABEL}.${PAGE_TYPE_MODEL}"
local_selector="a[href*=\"add/${PAGE_TYPE_APP_LABEL}/${PAGE_TYPE_MODEL}/\"]"
if element_exists "$local_selector"; then
    echo "  FOUND: ${PAGE_TYPE_APP_LABEL}.${PAGE_TYPE_MODEL}"
else
    echo "  NOT FOUND: ${PAGE_TYPE_APP_LABEL}.${PAGE_TYPE_MODEL}"
    echo "  You may need to update PAGE_TYPE_APP_LABEL and PAGE_TYPE_MODEL in .env"
fi

echo ""
echo "=== Discovery Step 2 complete ==="
