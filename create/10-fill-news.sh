#!/usr/bin/env bash
# create/10-fill-news.sh -- Fill the News & Events section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="news_events"
echo "=== Create Step 10: Fill News & Events Section ==="

section_json=$(get_section_data "$SECTION_ID")
block_sel=$(fill_section_standard_fields "$SECTION_ID")

# CTA
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")
if [[ -n "$cta_label" ]]; then
    fill_cta "$block_sel" "$cta_label" "$cta_url"
fi

take_named_screenshot "create-10-news-events"

echo "=== Create Step 10 complete ==="
