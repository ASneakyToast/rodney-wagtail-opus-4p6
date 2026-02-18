#!/usr/bin/env bash
# verify/verify-creation.sh -- Showboat document proving the page was created
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

SHOWBOAT="${SHOWBOAT_CMD:-uvx showboat}"
DOC="$SCRIPT_DIR/../docs/verify-creation.md"
mkdir -p "$(dirname "$DOC")"

echo "=== Verification: Page Creation ==="

$SHOWBOAT init "$DOC" "Verification: Design Strategy MBA Page Creation"

$SHOWBOAT note "$DOC" "## Environment

- **Admin URL:** ${WAGTAIL_ADMIN_URL}
- **Parent Page ID:** ${PARENT_PAGE_ID}
- **Page Type:** ${PAGE_TYPE_APP_LABEL}.${PAGE_TYPE_MODEL}
- **Verified:** $(date '+%Y-%m-%d %H:%M:%S')"

$SHOWBOAT note "$DOC" "## Step 1: Start browser and login"

$SHOWBOAT exec "$DOC" bash "
    echo 'Browser is already running, skipping start'
    $RODNEY_CMD open '${WAGTAIL_ADMIN_URL}/' 2>&1
    $RODNEY_CMD waitstable 2>&1
"

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD input '#id_username' '${WAGTAIL_USERNAME}' 2>&1
    $RODNEY_CMD input '#id_password' '${WAGTAIL_PASSWORD}' 2>&1
    $RODNEY_CMD click 'button[type=\"submit\"]' 2>&1
    $RODNEY_CMD waitstable 2>&1
    echo 'Login submitted'
"

$SHOWBOAT exec "$DOC" bash "$RODNEY_CMD title"

$SHOWBOAT note "$DOC" "## Step 2: Navigate to parent page and verify child exists"

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD open '${WAGTAIL_ADMIN_URL}/pages/${PARENT_PAGE_ID}/' 2>&1
    $RODNEY_CMD waitstable 2>&1
    echo '--- Page listing ---'
    $RODNEY_CMD text '.listing tbody' 2>&1 || echo '(no listing found)'
"

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD screenshot screenshots/verify-page-explorer.png 2>&1
    echo 'Screenshot saved'
"

$SHOWBOAT image "$DOC" "screenshots/verify-page-explorer.png"

$SHOWBOAT note "$DOC" "## Step 3: Verify page title in listing"

$SHOWBOAT exec "$DOC" bash "
    # Search for the Design Strategy MBA page in the listing
    $RODNEY_CMD js \"
        const rows = document.querySelectorAll('.listing tbody tr');
        const found = Array.from(rows).find(r => r.textContent.includes('Design Strategy MBA'));
        found ? 'FOUND: ' + found.querySelector('a')?.textContent?.trim() : 'NOT FOUND in page listing';
    \" 2>&1
"

$SHOWBOAT note "$DOC" "## Step 4: Open the page edit view"

$SHOWBOAT exec "$DOC" bash "
    # Click into the Design Strategy MBA page
    $RODNEY_CMD js \"
        const links = document.querySelectorAll('.listing a');
        const link = Array.from(links).find(a => a.textContent.includes('Design Strategy MBA'));
        if (link) { link.click(); 'Clicked page link'; } else { 'Page link not found'; }
    \" 2>&1
    $RODNEY_CMD waitstable 2>&1
"

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD screenshot screenshots/verify-page-edit.png 2>&1
    echo 'Screenshot saved'
"

$SHOWBOAT image "$DOC" "screenshots/verify-page-edit.png"

$SHOWBOAT note "$DOC" "## Cleanup"

# Browser is managed externally; not stopping rodney here
echo "  Browser left running (managed externally)"

echo "  Showboat document created: $DOC"
echo "=== Verification complete ==="
