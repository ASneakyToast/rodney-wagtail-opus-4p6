#!/usr/bin/env bash
# create/06-fill-studios.sh -- Fill the Studios & Shops section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="studios_shops"
echo "=== Create Step 6: Fill Studios & Shops Section ==="

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

# 3. Small CTA block: first CTA from ctas array
cta_label=$(section_field "$section_json" ".fields.ctas[0].label")
cta_url=$(section_field "$section_json" ".fields.ctas[0].url")
if [[ -n "$cta_label" ]]; then
    add_cta_block "$cta_label" "$cta_url"
fi

# 4. Paragraph block: secondary_body
sec_body=$(section_field "$section_json" ".fields.secondary_body")
if [[ -n "$sec_body" ]]; then
    add_paragraph_block "$sec_body"
fi

# 5. Paragraph block: one_up.body
one_up_body=$(section_field "$section_json" ".fields.one_up.body")
if [[ -n "$one_up_body" ]]; then
    add_paragraph_block "$one_up_body"
fi

# 6. Small CTA block: one_up.cta
one_up_cta_label=$(section_field "$section_json" ".fields.one_up.cta_label")
one_up_cta_url=$(section_field "$section_json" ".fields.one_up.cta_url")
if [[ -n "$one_up_cta_label" ]]; then
    add_cta_block "$one_up_cta_label" "$one_up_cta_url"
fi

take_named_screenshot "create-06-studios-shops"

echo "=== Create Step 6 complete ==="
