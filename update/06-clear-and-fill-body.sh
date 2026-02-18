#!/usr/bin/env bash
# update/06-clear-and-fill-body.sh -- Clear existing body blocks and fill with new content
# This is the core update script: it removes existing StreamField blocks and adds
# fresh content from the data file, section by section.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

echo "=== Update Step 6: Clear and Fill Body StreamField ==="

# Step 1: Clear all existing blocks
echo ""
echo "--- Clearing Existing Blocks ---"
streamfield_clear_all_blocks "body"
take_named_screenshot "update-06-blocks-cleared"
echo "--------------------------------"

# Step 2: Fill sections from data file (same as create workflow)
echo ""
echo "--- Filling Sections ---"

# Section 1: Overview
echo ""
echo "  [1/7] Overview"
section_json=$(get_section_data "overview")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
video_url=$(section_field "$section_json" ".fields.video_embed")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
quote=$(section_field "$section_json" ".fields.pull_quote.quote")
attribution=$(section_field "$section_json" ".fields.pull_quote.attribution")

add_heading_block "$headline" "$subhead"
[[ -n "$body" ]] && add_paragraph_block "$body"
[[ -n "$video_url" ]] && add_embed_block "$video_url"
[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"
[[ -n "$quote" ]] && add_quote_block "$quote" "$attribution"
take_named_screenshot "update-06-overview"

# Section 2: Studios & Shops
echo ""
echo "  [2/7] Studios & Shops"
section_json=$(get_section_data "studios_shops")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
one_up_body=$(section_field "$section_json" ".fields.one_up.body")
one_up_cta_label=$(section_field "$section_json" ".fields.one_up.cta_label")
one_up_cta_url=$(section_field "$section_json" ".fields.one_up.cta_url")

add_heading_block "$headline" "$subhead"
[[ -n "$body" ]] && add_paragraph_block "$body"

# CTA from ctas array
cta_label=$(echo "$section_json" | jq -r '.fields.ctas[0].label // empty')
cta_url=$(echo "$section_json" | jq -r '.fields.ctas[0].url // empty')
[[ -n "$cta_label" ]] && add_cta_block "$cta_label" "$cta_url"

[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"
[[ -n "$one_up_body" ]] && add_paragraph_block "$one_up_body"
[[ -n "$one_up_cta_label" ]] && add_cta_block "$one_up_cta_label" "$one_up_cta_url"
take_named_screenshot "update-06-studios"

# Section 3: Faculty
echo ""
echo "  [3/7] Faculty"
section_json=$(get_section_data "faculty")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")

# Combine faculty body with featured faculty info
faculty_name=$(section_field "$section_json" ".fields.featured_faculty.name")
faculty_bio=$(section_field "$section_json" ".fields.featured_faculty.bio")
combined_body="$body"
if [[ -n "$faculty_name" ]]; then
    combined_body="${body}\n\n${faculty_name}: ${faculty_bio}"
fi

cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")

add_heading_block "$headline" "$subhead"
[[ -n "$combined_body" ]] && add_paragraph_block "$combined_body"
[[ -n "$cta_label" ]] && add_cta_block "$cta_label" "$cta_url"
take_named_screenshot "update-06-faculty"

# Section 4: Curriculum
echo ""
echo "  [4/7] Curriculum"
section_json=$(get_section_data "curriculum")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
quote=$(section_field "$section_json" ".fields.pull_quote.quote")
attribution=$(section_field "$section_json" ".fields.pull_quote.attribution")

add_heading_block "$headline" "$subhead"
[[ -n "$body" ]] && add_paragraph_block "$body"
[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"
[[ -n "$quote" ]] && add_quote_block "$quote" "$attribution"
take_named_screenshot "update-06-curriculum"

# Section 5: Careers
echo ""
echo "  [5/7] Careers"
section_json=$(get_section_data "careers")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
sec_body=$(section_field "$section_json" ".fields.secondary_body")

add_heading_block "$headline" "$subhead"
[[ -n "$body" ]] && add_paragraph_block "$body"
[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"
take_named_screenshot "update-06-careers"

# Section 6: News & Events
echo ""
echo "  [6/7] News & Events"
section_json=$(get_section_data "news_events")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")

add_heading_block "$headline" "$subhead"
[[ -n "$body" ]] && add_paragraph_block "$body"
[[ -n "$cta_label" ]] && add_cta_block "$cta_label" "$cta_url"
take_named_screenshot "update-06-news"

# Section 7: How to Apply
echo ""
echo "  [7/7] How to Apply"
section_json=$(get_section_data "how_to_apply")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")

add_heading_block "$headline" "${subhead:-}"
[[ -n "$body" ]] && add_paragraph_block "$body"
[[ -n "$cta_label" ]] && add_cta_block "$cta_label" "$cta_url"
take_named_screenshot "update-06-apply"

echo "------------------------"

# Final block count
FINAL_COUNT=$(streamfield_count_blocks "body")
echo ""
echo "  Body StreamField now has ${FINAL_COUNT} blocks."
take_named_screenshot "update-06-all-sections-filled"

echo ""
echo "=== Update Step 6 complete ==="
