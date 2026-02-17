#!/usr/bin/env bash
# create/09-fill-careers.sh -- Fill the Careers section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="careers"
echo "=== Create Step 9: Fill Careers Section ==="

section_json=$(get_section_data "$SECTION_ID")
block_sel=$(fill_section_standard_fields "$SECTION_ID")

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

# Alumni stories as a list
alumni_count=$(echo "$section_json" | jq -r '.fields.alumni_stories | length')
echo "  Alumni stories: ${alumni_count} entries"

# Build alumni list as rich text content for a Draftail field
# This creates a formatted list of links
alumni_text=""
for ((i = 0; i < alumni_count; i++)); do
    name=$(echo "$section_json" | jq -r ".fields.alumni_stories[$i].name")
    url=$(echo "$section_json" | jq -r ".fields.alumni_stories[$i].url")
    if [[ -n "$alumni_text" ]]; then
        alumni_text="${alumni_text}\n\n"
    fi
    alumni_text="${alumni_text}${name}: ${url}"
done

if [[ -n "$alumni_text" ]]; then
    echo "  Setting alumni stories content..."
    draftail_set_content "${block_sel} [data-contentpath=\"alumni_stories\"]" "$alumni_text"
    # Alternative field names
    draftail_set_content "${block_sel} [data-contentpath=\"featured_list\"]" "$alumni_text"
    draftail_set_content "${block_sel} [data-contentpath=\"success_stories\"]" "$alumni_text"
fi

take_named_screenshot "create-09-careers"

echo "=== Create Step 9 complete ==="
