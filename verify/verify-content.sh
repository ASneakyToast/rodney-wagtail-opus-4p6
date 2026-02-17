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

This document verifies that the published page content matches the source data file.

- **Data source:** data/design-strategy-mba.json
- **Verified:** $(date '+%Y-%m-%d %H:%M:%S')"

$SHOWBOAT note "$DOC" "## Step 1: Start browser and login"

$SHOWBOAT exec "$DOC" bash -c "
    $RODNEY_CMD start --local 2>&1 || true
    sleep 2
    $RODNEY_CMD open '${WAGTAIL_ADMIN_URL}/' 2>&1
    $RODNEY_CMD waitstable 2>&1
    $RODNEY_CMD input '#id_username' '${WAGTAIL_USERNAME}' 2>&1
    $RODNEY_CMD input '#id_password' '${WAGTAIL_PASSWORD}' 2>&1
    $RODNEY_CMD click 'button[type=\"submit\"]' 2>&1
    $RODNEY_CMD waitstable 2>&1
    echo 'Logged in'
"

$SHOWBOAT note "$DOC" "## Step 2: Navigate to the page edit form"

$SHOWBOAT exec "$DOC" bash -c "
    # Navigate to parent and find the page
    $RODNEY_CMD open '${WAGTAIL_ADMIN_URL}/pages/${PARENT_PAGE_ID}/' 2>&1
    $RODNEY_CMD waitstable 2>&1

    # Click the edit button for Design Strategy MBA
    $RODNEY_CMD js \"
        const rows = document.querySelectorAll('.listing tbody tr');
        const row = Array.from(rows).find(r => r.textContent.includes('Design Strategy MBA'));
        if (row) {
            const editBtn = row.querySelector('a[href*=\"/edit/\"]') || row.querySelector('a');
            if (editBtn) editBtn.click();
            'Navigating to edit form';
        } else {
            'Page not found in listing';
        }
    \" 2>&1
    $RODNEY_CMD waitstable 2>&1
"

$SHOWBOAT note "$DOC" "## Step 3: Verify page title"

EXPECTED_TITLE=$(jq -r '.page.title' "$DATA_FILE")
$SHOWBOAT exec "$DOC" bash -c "
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

    $SHOWBOAT exec "$DOC" bash -c "
        echo 'Expected headline: ${expected_headline}'
        # Try to find this section in the page form
        $RODNEY_CMD js \"
            const blocks = document.querySelectorAll('[data-streamfield-block]');
            let found = false;
            blocks.forEach(block => {
                const inputs = block.querySelectorAll('input');
                inputs.forEach(input => {
                    if (input.value.includes('${expected_headline}')) {
                        found = true;
                    }
                });
            });
            found ? 'FOUND in form' : 'Not found in form inputs (may be in rich text)';
        \" 2>&1
    "
done

$SHOWBOAT exec "$DOC" bash -c "
    $RODNEY_CMD screenshot screenshots/verify-content-form.png 2>&1
    echo 'Screenshot saved'
"

$SHOWBOAT image "$DOC" "screenshots/verify-content-form.png"

$SHOWBOAT note "$DOC" "## Cleanup"

$SHOWBOAT exec "$DOC" bash -c "$RODNEY_CMD stop 2>&1 || true"

echo "  Showboat document created: $DOC"
echo "=== Content verification complete ==="
