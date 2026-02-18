#!/usr/bin/env bash
# create/07-fill-faculty.sh -- Fill the Faculty section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="faculty"
echo "=== Create Step 7: Fill Faculty Section ==="

section_json=$(get_section_data "$SECTION_ID")

# 1. Heading block: headline + subhead
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
add_heading_block "$headline" "$subhead"

# 2. Paragraph block: body + featured faculty name and bio combined
body=$(section_field "$section_json" ".fields.body")
faculty_name=$(section_field "$section_json" ".fields.featured_faculty.name")
faculty_bio=$(section_field "$section_json" ".fields.featured_faculty.bio")

combined_body="$body"
if [[ -n "$faculty_name" && -n "$faculty_bio" ]]; then
    combined_body="${body}\n\n${faculty_name}: ${faculty_bio}"
fi

if [[ -n "$combined_body" ]]; then
    add_paragraph_block "$combined_body"
fi

# 3. Small CTA block: cta
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")
if [[ -n "$cta_label" ]]; then
    add_cta_block "$cta_label" "$cta_url"
fi

take_named_screenshot "create-07-faculty"

echo "=== Create Step 7 complete ==="
