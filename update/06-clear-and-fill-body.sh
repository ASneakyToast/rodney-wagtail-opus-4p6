#!/usr/bin/env bash
# update/06-clear-and-fill-body.sh -- Clear existing body blocks and fill with new content
# This is the core update script: it removes existing StreamField blocks and adds
# fresh content from the data file, section by section.
#
# Heading pattern: Each section uses a Nav Headline block (nav_heading + headline)
# followed by a Paragraph block with H3-formatted subhead text. This follows the
# standard implementation pattern for the flexible template.
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

# Step 2: Fill sections from data file
# Each section follows the pattern:
#   1. Nav Headline block (nav_heading=section_title, headline=fields.headline)
#   2. Subhead as Paragraph with H3 formatting (fields.subhead)
#   3. Body content blocks (paragraphs, embeds, quotes, CTAs)
#   4. Secondary subhead as Paragraph with H3 formatting (fields.secondary_subhead)
#   5. Secondary body content
echo ""
echo "--- Filling Sections ---"

# ========================================
# Section 1: Overview
# ========================================
echo ""
echo "  [1/7] Overview"
section_json=$(get_section_data "overview")
section_title=$(section_field "$section_json" ".section_title")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
video_url=$(section_field "$section_json" ".fields.video_embed")
sec_subhead=$(section_field "$section_json" ".fields.secondary_subhead")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
quote=$(section_field "$section_json" ".fields.pull_quote.quote")
attribution=$(section_field "$section_json" ".fields.pull_quote.attribution")

# Nav Headline: section_title as nav anchor, headline as display text
add_nav_headline_block "$section_title" "$headline"
# Subhead as H3 paragraph
[[ -n "$subhead" ]] && add_subhead_block "$subhead"
# Body copy
[[ -n "$body" ]] && add_paragraph_block "$body"
# Video embed
[[ -n "$video_url" ]] && add_embed_block "$video_url"
# Secondary subhead as H3 paragraph
[[ -n "$sec_subhead" ]] && add_subhead_block "$sec_subhead"
# Secondary body copy
[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"
# Pull quote
[[ -n "$quote" ]] && add_quote_block "$quote" "$attribution"
take_named_screenshot "update-06-overview"

# ========================================
# Section 2: Studios & Shops
# ========================================
echo ""
echo "  [2/7] Studios & Shops"
section_json=$(get_section_data "studios_shops")
section_title=$(section_field "$section_json" ".section_title")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
sec_subhead=$(section_field "$section_json" ".fields.secondary_subhead")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
one_up_headline=$(section_field "$section_json" ".fields.one_up.headline")
one_up_body=$(section_field "$section_json" ".fields.one_up.body")
one_up_cta_label=$(section_field "$section_json" ".fields.one_up.cta_label")
one_up_cta_url=$(section_field "$section_json" ".fields.one_up.cta_url")

# Nav Headline
add_nav_headline_block "$section_title" "$headline"
# Subhead as H3 paragraph
[[ -n "$subhead" ]] && add_subhead_block "$subhead"
# Body copy
[[ -n "$body" ]] && add_paragraph_block "$body"

# CTA from ctas array
cta_label=$(echo "$section_json" | jq -r '.fields.ctas[0].label // empty')
cta_url=$(echo "$section_json" | jq -r '.fields.ctas[0].url // empty')
[[ -n "$cta_label" ]] && add_cta_block "$cta_label" "$cta_url"

# Secondary subhead as H3 paragraph
[[ -n "$sec_subhead" ]] && add_subhead_block "$sec_subhead"
# Secondary body copy
[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"

# One-up content: headline as H3 + body + CTA
[[ -n "$one_up_headline" ]] && add_subhead_block "$one_up_headline"
[[ -n "$one_up_body" ]] && add_paragraph_block "$one_up_body"
[[ -n "$one_up_cta_label" ]] && add_cta_block "$one_up_cta_label" "$one_up_cta_url"
take_named_screenshot "update-06-studios"

# ========================================
# Section 3: Faculty
# ========================================
echo ""
echo "  [3/7] Faculty"
section_json=$(get_section_data "faculty")
section_title=$(section_field "$section_json" ".section_title")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")

# Featured faculty info
faculty_name=$(section_field "$section_json" ".fields.featured_faculty.name")
faculty_bio=$(section_field "$section_json" ".fields.featured_faculty.bio")

cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")

# Nav Headline
add_nav_headline_block "$section_title" "$headline"
# Subhead as H3 paragraph
[[ -n "$subhead" ]] && add_subhead_block "$subhead"
# Body copy
[[ -n "$body" ]] && add_paragraph_block "$body"
# Featured faculty as separate paragraph (name as subhead, bio as body)
if [[ -n "$faculty_name" ]]; then
    add_subhead_block "$faculty_name" "header-four"
    [[ -n "$faculty_bio" ]] && add_paragraph_block "$faculty_bio"
fi
# CTA
[[ -n "$cta_label" ]] && add_cta_block "$cta_label" "$cta_url"
take_named_screenshot "update-06-faculty"

# ========================================
# Section 4: Curriculum
# ========================================
echo ""
echo "  [4/7] Curriculum"
section_json=$(get_section_data "curriculum")
section_title=$(section_field "$section_json" ".section_title")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
sec_subhead=$(section_field "$section_json" ".fields.secondary_subhead")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
quote=$(section_field "$section_json" ".fields.pull_quote.quote")
attribution=$(section_field "$section_json" ".fields.pull_quote.attribution")

# Nav Headline
add_nav_headline_block "$section_title" "$headline"
# Subhead as H3 paragraph
[[ -n "$subhead" ]] && add_subhead_block "$subhead"
# Body copy
[[ -n "$body" ]] && add_paragraph_block "$body"
# Secondary subhead as H3 paragraph
[[ -n "$sec_subhead" ]] && add_subhead_block "$sec_subhead"
# Secondary body copy
[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"
# Pull quote
[[ -n "$quote" ]] && add_quote_block "$quote" "$attribution"
take_named_screenshot "update-06-curriculum"

# ========================================
# Section 5: Careers
# ========================================
echo ""
echo "  [5/7] Careers"
section_json=$(get_section_data "careers")
section_title=$(section_field "$section_json" ".section_title")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
sec_subhead=$(section_field "$section_json" ".fields.secondary_subhead")
sec_body=$(section_field "$section_json" ".fields.secondary_body")

# Nav Headline
add_nav_headline_block "$section_title" "$headline"
# Subhead as H3 paragraph
[[ -n "$subhead" ]] && add_subhead_block "$subhead"
# Body copy
[[ -n "$body" ]] && add_paragraph_block "$body"
# Secondary subhead as H3 paragraph
[[ -n "$sec_subhead" ]] && add_subhead_block "$sec_subhead"
# Secondary body copy
[[ -n "$sec_body" ]] && add_paragraph_block "$sec_body"

# Alumni stories as linked paragraph block
alumni_json=$(echo "$section_json" | jq -c '.fields.alumni_stories // empty')
if [[ -n "$alumni_json" ]] && [[ "$alumni_json" != "null" ]]; then
    add_subhead_block "Alumni Stories" "header-four"
    add_alumni_block "$alumni_json"
fi
take_named_screenshot "update-06-careers"

# ========================================
# Section 6: News & Events
# ========================================
echo ""
echo "  [6/7] News & Events"
section_json=$(get_section_data "news_events")
section_title=$(section_field "$section_json" ".section_title")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")

# Nav Headline
add_nav_headline_block "$section_title" "$headline"
# Subhead as H3 paragraph
[[ -n "$subhead" ]] && add_subhead_block "$subhead"
# Body copy
[[ -n "$body" ]] && add_paragraph_block "$body"
# CTA
[[ -n "$cta_label" ]] && add_cta_block "$cta_label" "$cta_url"
take_named_screenshot "update-06-news"

# ========================================
# Section 7: How to Apply
# ========================================
echo ""
echo "  [7/7] How to Apply"
section_json=$(get_section_data "how_to_apply")
section_title=$(section_field "$section_json" ".section_title")
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
body=$(section_field "$section_json" ".fields.body")
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")

# Nav Headline
add_nav_headline_block "$section_title" "$headline"
# Subhead as H3 paragraph (if present)
[[ -n "$subhead" ]] && add_subhead_block "$subhead"
# Body copy
[[ -n "$body" ]] && add_paragraph_block "$body"
# CTA
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
