#!/usr/bin/env bash
# create/05-fill-overview.sh -- Fill the Overview section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="overview"
echo "=== Create Step 5: Fill Overview Section ==="

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

# 3. Embed block: video_embed
video_url=$(section_field "$section_json" ".fields.video_embed")
if [[ -n "$video_url" ]]; then
    add_embed_block "$video_url"
fi

# 4. Paragraph block: secondary_body
sec_body=$(section_field "$section_json" ".fields.secondary_body")
if [[ -n "$sec_body" ]]; then
    add_paragraph_block "$sec_body"
fi

# 5. Quote block: pull_quote
quote=$(section_field "$section_json" ".fields.pull_quote.quote")
attribution=$(section_field "$section_json" ".fields.pull_quote.attribution")
if [[ -n "$quote" ]]; then
    add_quote_block "$quote" "$attribution"
fi

take_named_screenshot "create-05-overview"

echo "=== Create Step 5 complete ==="
