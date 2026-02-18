#!/usr/bin/env bash
# create/11-fill-apply.sh -- Fill the How to Apply section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="how_to_apply"
echo "=== Create Step 11: Fill How to Apply Section ==="

section_json=$(get_section_data "$SECTION_ID")

# 1. Heading block: headline only (no subhead for this section)
headline=$(section_field "$section_json" ".fields.headline")
add_heading_block "$headline" ""

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

take_named_screenshot "create-11-how-to-apply"

echo "=== Create Step 11 complete ==="
