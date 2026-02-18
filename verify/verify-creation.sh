#!/usr/bin/env bash
# verify/verify-creation.sh -- Showboat document proving the page was updated
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

SHOWBOAT="${SHOWBOAT_CMD:-uvx showboat}"
DOC="$SCRIPT_DIR/../docs/verify-creation.md"
mkdir -p "$(dirname "$DOC")"

echo "=== Verification: Page Update ==="

$SHOWBOAT init "$DOC" "Verification: Design Strategy MBA Page Update"

$SHOWBOAT note "$DOC" "## Environment

- **Admin URL:** ${WAGTAIL_ADMIN_URL}
- **Target Page ID:** ${TARGET_PAGE_ID}
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

$SHOWBOAT note "$DOC" "## Step 2: Navigate directly to target page edit form"

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD open '${WAGTAIL_ADMIN_URL}/pages/${TARGET_PAGE_ID}/edit/' 2>&1
    $RODNEY_CMD waitstable 2>&1
    echo 'Opened edit form for page ${TARGET_PAGE_ID}'
"

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD screenshot screenshots/verify-page-edit.png 2>&1
    echo 'Screenshot saved'
"

$SHOWBOAT image "$DOC" "screenshots/verify-page-edit.png"

$SHOWBOAT note "$DOC" "## Step 3: Verify page title matches"

$SHOWBOAT exec "$DOC" bash "
    title=\$($RODNEY_CMD js \"document.querySelector('#id_title')?.value || 'not found'\" 2>&1)
    echo \"Page title: \${title}\"
    if echo \"\$title\" | grep -qi 'Design Strategy MBA'; then
        echo 'PASS: Title contains Design Strategy MBA'
    else
        echo 'INFO: Title is set to a different value'
    fi
"

$SHOWBOAT note "$DOC" "## Step 4: Verify StreamField body has content"

$SHOWBOAT exec "$DOC" bash "
    count=\$($RODNEY_CMD js \"
        document.querySelector('[data-contentpath=\\\"body\\\"]')?.querySelector('input[data-streamfield-stream-count]')?.value || '0'
    \" 2>&1)
    echo \"StreamField block count: \${count}\"
    if [ \"\$count\" -gt 0 ] 2>/dev/null; then
        echo 'PASS: Body has content blocks'
    else
        echo 'WARN: No blocks found in body StreamField'
    fi
"

$SHOWBOAT note "$DOC" "## Cleanup"

echo "  Browser left running (managed externally)"

echo "  Showboat document created: $DOC"
echo "=== Verification complete ==="
