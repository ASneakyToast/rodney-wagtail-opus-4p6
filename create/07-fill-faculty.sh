#!/usr/bin/env bash
# create/07-fill-faculty.sh -- Fill the Faculty section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="faculty"
echo "=== Create Step 7: Fill Faculty Section ==="

section_json=$(get_section_data "$SECTION_ID")
block_sel=$(fill_section_standard_fields "$SECTION_ID")

# Featured faculty bio
faculty_name=$(section_field "$section_json" ".fields.featured_faculty.name")
faculty_bio=$(section_field "$section_json" ".fields.featured_faculty.bio")

if [[ -n "$faculty_name" ]]; then
    echo "  Featured faculty: ${faculty_name}"
    streamfield_fill_field "$block_sel" "faculty_name" "$faculty_name"
    streamfield_fill_field "$block_sel" "featured_name" "$faculty_name"
fi
if [[ -n "$faculty_bio" ]]; then
    echo "  Setting faculty bio..."
    draftail_set_content "${block_sel} [data-contentpath=\"faculty_bio\"]" "$faculty_bio"
    # Try alternative field names
    draftail_set_content "${block_sel} [data-contentpath=\"featured_bio\"]" "$faculty_bio"
fi

# CTA
cta_label=$(section_field "$section_json" ".fields.cta.label")
cta_url=$(section_field "$section_json" ".fields.cta.url")
if [[ -n "$cta_label" ]]; then
    fill_cta "$block_sel" "$cta_label" "$cta_url"
fi

take_named_screenshot "create-07-faculty"

echo "=== Create Step 7 complete ==="
