#!/usr/bin/env bash
# verify/verify-published.sh -- Showboat document proving the page is live
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

SHOWBOAT="${SHOWBOAT_CMD:-uvx showboat}"
DOC="$SCRIPT_DIR/../docs/verify-published.md"
mkdir -p "$(dirname "$DOC")"

# Derive the public site URL from the admin URL
# e.g., https://www.example.com/admin/ -> https://www.example.com/
PUBLIC_URL="${PUBLIC_SITE_URL:-$(echo "$WAGTAIL_ADMIN_URL" | sed 's|/admin.*||')}"
PAGE_SLUG=$(jq -r '.page.slug' "$SCRIPT_DIR/../data/design-strategy-mba.json")

echo "=== Verification: Published Page ==="

$SHOWBOAT init "$DOC" "Verification: Design Strategy MBA Published Page"

$SHOWBOAT note "$DOC" "## Overview

This document verifies that the Design Strategy MBA page is live and accessible on the public site.

- **Public URL:** ${PUBLIC_URL}
- **Page slug:** ${PAGE_SLUG}
- **Verified:** $(date '+%Y-%m-%d %H:%M:%S')"

$SHOWBOAT note "$DOC" "## Step 1: Start browser"

$SHOWBOAT exec "$DOC" bash -c "
    $RODNEY_CMD start --local 2>&1 || true
    sleep 2
    echo 'Browser started'
"

$SHOWBOAT note "$DOC" "## Step 2: Visit the published page"

$SHOWBOAT exec "$DOC" bash -c "
    $RODNEY_CMD open '${PUBLIC_URL}/${PAGE_SLUG}/' 2>&1
    $RODNEY_CMD waitstable 2>&1
    echo 'Page loaded'
"

$SHOWBOAT exec "$DOC" bash -c "$RODNEY_CMD title 2>&1"
$SHOWBOAT exec "$DOC" bash -c "$RODNEY_CMD url 2>&1"

$SHOWBOAT exec "$DOC" bash -c "
    $RODNEY_CMD screenshot screenshots/verify-published-full.png 2>&1
    echo 'Full page screenshot saved'
"

$SHOWBOAT image "$DOC" "screenshots/verify-published-full.png"

$SHOWBOAT note "$DOC" "## Step 3: Verify key content is present on the live page"

# Check for each section headline on the public page
SECTION_IDS=$(jq -r '.sections[].id' "$SCRIPT_DIR/../data/design-strategy-mba.json")
for section_id in $SECTION_IDS; do
    expected_headline=$(jq -r ".sections[] | select(.id == \"${section_id}\") | .fields.headline" "$SCRIPT_DIR/../data/design-strategy-mba.json")

    $SHOWBOAT exec "$DOC" bash -c "
        result=\$($RODNEY_CMD js \"
            document.body.textContent.includes('${expected_headline}') ? 'FOUND' : 'NOT FOUND';
        \" 2>&1)
        echo 'Section ${section_id}: ${expected_headline} -> '\"\$result\"
    "
done

$SHOWBOAT note "$DOC" "## Step 4: Section-by-section screenshots"

SECTIONS=("overview" "studios_shops" "faculty" "curriculum" "careers" "news_events" "how_to_apply")
for section_id in "${SECTIONS[@]}"; do
    expected_headline=$(jq -r ".sections[] | select(.id == \"${section_id}\") | .fields.headline" "$SCRIPT_DIR/../data/design-strategy-mba.json")

    $SHOWBOAT exec "$DOC" bash -c "
        # Try to scroll to the section and take a screenshot
        $RODNEY_CMD js \"
            const headings = document.querySelectorAll('h1, h2, h3, h4');
            const heading = Array.from(headings).find(h => h.textContent.includes('${expected_headline}'));
            if (heading) {
                heading.scrollIntoView({ behavior: 'instant', block: 'start' });
                'Scrolled to: ${expected_headline}';
            } else {
                'Heading not found: ${expected_headline}';
            }
        \" 2>&1
        sleep 0.5
        $RODNEY_CMD screenshot screenshots/verify-published-${section_id}.png 2>&1
        echo 'Screenshot saved for ${section_id}'
    "

    $SHOWBOAT image "$DOC" "screenshots/verify-published-${section_id}.png"
done

$SHOWBOAT note "$DOC" "## Cleanup"

$SHOWBOAT exec "$DOC" bash -c "$RODNEY_CMD stop 2>&1 || true"

echo "  Showboat document created: $DOC"
echo "=== Published page verification complete ==="
