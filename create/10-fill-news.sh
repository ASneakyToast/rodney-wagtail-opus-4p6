#!/usr/bin/env bash
# create/10-fill-news.sh -- Fill the News & Events section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="news_events"
echo "=== Create Step 10: Fill News & Events Section ==="

section_json=$(get_section_data "$SECTION_ID")

# 1. Heading block: headline + subhead
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
add_heading_block "$headline" "$subhead"

# 2. Paragraph block: body
body=$(section_field "$section_json" ".fields.body")
if [[ -n "$body" ]]; then
    add_paragraph_block "$body"
fi

# 3. Small CTA block: cta
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")
if [[ -n "$cta_label" ]]; then
    add_cta_block "$cta_label" "$cta_url"
fi

take_named_screenshot "create-10-news-events"

echo "=== Create Step 10 complete ==="
