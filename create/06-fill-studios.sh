#!/usr/bin/env bash
# create/06-fill-studios.sh -- Fill the Studios & Shops section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="studios_shops"
echo "=== Create Step 6: Fill Studios & Shops Section ==="

section_json=$(get_section_data "$SECTION_ID")
block_sel=$(fill_section_standard_fields "$SECTION_ID")

# CTAs
cta_count=$(echo "$section_json" | jq -r '.fields.ctas | length')
for ((i = 0; i < cta_count; i++)); do
    cta_label=$(echo "$section_json" | jq -r ".fields.ctas[$i].label")
    cta_url=$(echo "$section_json" | jq -r ".fields.ctas[$i].url")
    fill_cta "$block_sel" "$cta_label" "$cta_url"
done

# Secondary subhead and body
sec_subhead=$(section_field "$section_json" ".fields.secondary_subhead")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
if [[ -n "$sec_subhead" ]]; then
    echo "  Secondary subhead: ${sec_subhead}"
    streamfield_fill_field "$block_sel" "secondary_subhead" "$sec_subhead"
fi
if [[ -n "$sec_body" ]]; then
    echo "  Setting secondary body content..."
    draftail_set_content "${block_sel} [data-contentpath=\"secondary_body\"]" "$sec_body"
fi

# One-up / featured content
one_up_headline=$(section_field "$section_json" ".fields.one_up.headline")
one_up_body=$(section_field "$section_json" ".fields.one_up.body")
one_up_cta_label=$(section_field "$section_json" ".fields.one_up.cta_label")
one_up_cta_url=$(section_field "$section_json" ".fields.one_up.cta_url")

if [[ -n "$one_up_headline" ]]; then
    echo "  One-up: ${one_up_headline}"
    streamfield_fill_field "$block_sel" "one_up_headline" "$one_up_headline"
    streamfield_fill_field "$block_sel" "featured_headline" "$one_up_headline"
fi
if [[ -n "$one_up_body" ]]; then
    draftail_set_content "${block_sel} [data-contentpath=\"one_up_body\"]" "$one_up_body"
fi
if [[ -n "$one_up_cta_label" ]]; then
    streamfield_fill_field "$block_sel" "one_up_cta_label" "$one_up_cta_label"
    streamfield_fill_field "$block_sel" "one_up_cta_url" "$one_up_cta_url"
fi

take_named_screenshot "create-06-studios-shops"

echo "=== Create Step 6 complete ==="
