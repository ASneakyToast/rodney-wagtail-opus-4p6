#!/usr/bin/env bash
# lib/section-helpers.sh -- Common helpers for section-filling scripts
# Source after all config and library files are loaded.

DATA_FILE="${DATA_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/data/design-strategy-mba.json}"

# Read a section's data by ID
# Usage: section_json=$(get_section_data "overview")
get_section_data() {
    local section_id="$1"
    jq -r ".sections[] | select(.id == \"${section_id}\")" "$DATA_FILE"
}

# Read a field from section JSON
# Usage: value=$(section_field "$section_json" ".fields.headline")
section_field() {
    local json="$1"
    local path="$2"
    echo "$json" | jq -r "$path // empty"
}

# Fill a section's standard fields (headline, subhead, body) in the last StreamField block
# Usage: fill_section_standard_fields "overview"
fill_section_standard_fields() {
    local section_id="$1"
    local section_json
    section_json=$(get_section_data "$section_id")

    local block_type headline subhead body
    block_type=$(section_field "$section_json" ".block_type")
    headline=$(section_field "$section_json" ".fields.headline")
    subhead=$(section_field "$section_json" ".fields.subhead")
    body=$(section_field "$section_json" ".fields.body")

    # Add the block
    streamfield_add_block "body" "$block_type"

    # Get selector for the new block
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    # Fill headline
    if [[ -n "$headline" ]]; then
        echo "  Headline: ${headline}"
        streamfield_fill_field "$block_sel" "headline" "$headline"
    fi

    # Fill subhead
    if [[ -n "$subhead" ]]; then
        echo "  Subhead: ${subhead}"
        streamfield_fill_field "$block_sel" "subhead" "$subhead"
    fi

    # Fill body (rich text)
    if [[ -n "$body" ]]; then
        echo "  Setting body content..."
        draftail_set_content "${block_sel} [data-contentpath=\"body\"]" "$body"
    fi

    # Return the block selector for further customization
    echo "$block_sel"
}

# Fill a CTA (call-to-action) sub-block within a parent block
fill_cta() {
    local parent_selector="$1"
    local label="$2"
    local url="$3"

    echo "  CTA: ${label} -> ${url}"
    streamfield_fill_field "$parent_selector" "cta_label" "$label"
    streamfield_fill_field "$parent_selector" "cta_url" "$url"

    # Alternative field names
    streamfield_fill_field "$parent_selector" "button_text" "$label"
    streamfield_fill_field "$parent_selector" "button_url" "$url"
    streamfield_fill_field "$parent_selector" "link_text" "$label"
    streamfield_fill_field "$parent_selector" "link_url" "$url"
}

# Fill a pull quote sub-block
fill_pull_quote() {
    local parent_selector="$1"
    local quote="$2"
    local attribution="$3"

    echo "  Pull quote: \"${quote:0:50}...\" -- ${attribution}"
    streamfield_fill_field "$parent_selector" "quote" "$quote"
    streamfield_fill_field "$parent_selector" "attribution" "$attribution"
    # Alternative names
    streamfield_fill_field "$parent_selector" "pull_quote" "$quote"
    streamfield_fill_field "$parent_selector" "quote_attribution" "$attribution"
}
