#!/usr/bin/env bash
# create/04-fill-basic-fields.sh -- Fill the page title, slug, and SEO fields
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

DATA_FILE="$SCRIPT_DIR/../data/design-strategy-mba.json"

echo "=== Create Step 4: Fill Basic Fields ==="

PAGE_TITLE=$(jq -r '.page.title' "$DATA_FILE")
PAGE_SLUG=$(jq -r '.page.slug' "$DATA_FILE")
SEO_TITLE=$(jq -r '.page.seo_title // empty' "$DATA_FILE")
SEARCH_DESC=$(jq -r '.page.search_description // empty' "$DATA_FILE")

# Fill title
echo "  Setting title: ${PAGE_TITLE}"
rodney_safe_input "$SEL_PAGE_TITLE" "$PAGE_TITLE"

# Wait for slug auto-generation, then override if needed
sleep 1
$RODNEY_CMD waitstable

# Check if slug needs updating
current_slug=$($RODNEY_CMD js "document.querySelector('${SEL_PAGE_SLUG}').value" 2>/dev/null || echo "")
if [[ "$current_slug" != "$PAGE_SLUG" ]]; then
    echo "  Setting slug: ${PAGE_SLUG}"
    rodney_safe_input "$SEL_PAGE_SLUG" "$PAGE_SLUG"
fi

take_named_screenshot "create-04-basic-fields"

# Fill SEO/Promote tab fields if present
if [[ -n "$SEO_TITLE" ]] || [[ -n "$SEARCH_DESC" ]]; then
    echo "  Switching to Promote tab..."
    if element_exists "$SEL_TAB_PROMOTE"; then
        rodney_cmd click "$SEL_TAB_PROMOTE"
        $RODNEY_CMD waitstable

        if [[ -n "$SEO_TITLE" ]]; then
            echo "  Setting SEO title: ${SEO_TITLE}"
            rodney_safe_input '#id_seo_title' "$SEO_TITLE"
        fi

        if [[ -n "$SEARCH_DESC" ]]; then
            echo "  Setting search description..."
            rodney_safe_input '#id_search_description' "$SEARCH_DESC"
        fi

        take_named_screenshot "create-04-promote-tab"

        # Switch back to Content tab
        if element_exists "$SEL_TAB_CONTENT"; then
            rodney_cmd click "$SEL_TAB_CONTENT"
            $RODNEY_CMD waitstable
        fi
    else
        echo "  [info] Promote tab not found, skipping SEO fields."
    fi
fi

echo "=== Create Step 4 complete ==="
