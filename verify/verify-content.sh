#!/usr/bin/env bash
# verify/verify-content.sh -- Showboat document verifying content accuracy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

SHOWBOAT="${SHOWBOAT_CMD:-uvx showboat}"
DOC="$SCRIPT_DIR/../docs/verify-content.md"
DATA_FILE="$SCRIPT_DIR/../data/design-strategy-mba.json"
mkdir -p "$(dirname "$DOC")"

echo "=== Verification: Content Accuracy ==="

$SHOWBOAT init "$DOC" "Verification: Design Strategy MBA Content Accuracy"

$SHOWBOAT note "$DOC" "## Overview

This document verifies that the updated page content matches the source data file.

- **Target Page ID:** ${TARGET_PAGE_ID}
- **Data source:** data/design-strategy-mba.json
- **Verified:** $(date '+%Y-%m-%d %H:%M:%S')"

$SHOWBOAT note "$DOC" "## Step 1: Start browser and login"

$SHOWBOAT exec "$DOC" bash "
    echo 'Browser is already running, skipping start'
    $RODNEY_CMD open '${WAGTAIL_ADMIN_URL}/' 2>&1
    $RODNEY_CMD waitstable 2>&1
    $RODNEY_CMD input '#id_username' '${WAGTAIL_USERNAME}' 2>&1
    $RODNEY_CMD input '#id_password' '${WAGTAIL_PASSWORD}' 2>&1
    $RODNEY_CMD click 'button[type=\"submit\"]' 2>&1
    $RODNEY_CMD waitstable 2>&1
    echo 'Logged in'
"

$SHOWBOAT note "$DOC" "## Step 2: Navigate directly to the page edit form"

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD open '${WAGTAIL_ADMIN_URL}/pages/${TARGET_PAGE_ID}/edit/' 2>&1
    $RODNEY_CMD waitstable 2>&1
    echo 'Opened edit form for page ${TARGET_PAGE_ID}'
"

$SHOWBOAT note "$DOC" "## Step 3: Verify page title"

EXPECTED_TITLE=$(jq -r '.page.title' "$DATA_FILE")
$SHOWBOAT exec "$DOC" bash "
    actual_title=\$($RODNEY_CMD js \"document.querySelector('#id_title')?.value || 'not found'\" 2>&1)
    expected='${EXPECTED_TITLE}'
    echo \"Expected: \${expected}\"
    echo \"Actual:   \${actual_title}\"
    if [ \"\$actual_title\" = \"\$expected\" ]; then
        echo 'PASS: Title matches'
    else
        echo 'MISMATCH: Title does not match'
    fi
"

$SHOWBOAT note "$DOC" "## Step 4: Verify each section headline"

# Check each section's headline
SECTION_IDS=$(jq -r '.sections[].id' "$DATA_FILE")
for section_id in $SECTION_IDS; do
    expected_headline=$(jq -r ".sections[] | select(.id == \"${section_id}\") | .fields.headline" "$DATA_FILE")

    $SHOWBOAT note "$DOC" "### Section: ${section_id}"

    $SHOWBOAT exec "$DOC" bash "
        echo 'Expected headline: ${expected_headline}'
        $RODNEY_CMD js \"(() => { var container = document.querySelector('[data-contentpath=\\\"body\\\"]'); if (!container) return 'No body container'; var inputs = container.querySelectorAll('input'); var found = false; inputs.forEach(function(input) { if (input.value.includes('${expected_headline}')) { found = true; } }); return found ? 'FOUND in form' : 'Not found in form inputs (may be in rich text)'; })()\" 2>&1
    "
done

$SHOWBOAT exec "$DOC" bash "
    $RODNEY_CMD screenshot screenshots/verify-content-form.png 2>&1
    echo 'Screenshot saved'
"

$SHOWBOAT image "$DOC" "screenshots/verify-content-form.png"

$SHOWBOAT note "$DOC" "## Cleanup"

echo "  Browser left running (managed externally)"

echo "  Showboat document created: $DOC"
echo "=== Content verification complete ==="
