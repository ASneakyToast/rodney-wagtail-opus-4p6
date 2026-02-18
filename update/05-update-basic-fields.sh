#!/usr/bin/env bash
# update/05-update-basic-fields.sh -- Update page title, slug, and SEO fields
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"

DATA_FILE="$SCRIPT_DIR/../data/design-strategy-mba.json"

echo "=== Update Step 5: Update Basic Fields ==="

PAGE_TITLE=$(jq -r '.page.title' "$DATA_FILE")
PAGE_SUBHEAD=$(jq -r '.page.subhead // empty' "$DATA_FILE")
PAGE_SLUG=$(jq -r '.page.slug' "$DATA_FILE")
SEO_TITLE=$(jq -r '.page.seo_title // empty' "$DATA_FILE")
SEARCH_DESC=$(jq -r '.page.search_description // empty' "$DATA_FILE")

# Ensure we're on the Content tab
if element_exists "$SEL_TAB_CONTENT" 2>/dev/null; then
    rodney_cmd click "$SEL_TAB_CONTENT"
    $RODNEY_CMD waitstable
fi

# Update title (check if it exists and is visible first)
title_exists=$($RODNEY_CMD js "document.querySelector('${SEL_PAGE_TITLE}') ? 'yes' : 'no'" 2>/dev/null || echo "no")
if [[ "$title_exists" == "yes" ]]; then
    current_title=$($RODNEY_CMD js "document.querySelector('${SEL_PAGE_TITLE}')?.value || ''" 2>/dev/null || echo "")
    echo "  Current title: ${current_title}"
    echo "  New title: ${PAGE_TITLE}"
    if [[ "$current_title" != "$PAGE_TITLE" ]]; then
        # Use JS to set value directly (avoids visibility/wait issues)
        $RODNEY_CMD js "
            const el = document.querySelector('${SEL_PAGE_TITLE}');
            if (el) {
                el.value = '${PAGE_TITLE}';
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
            }
        " 2>/dev/null
        echo "  Title updated."
    else
        echo "  Title already correct, skipping."
    fi
else
    echo "  [info] Title field not found on Content tab."
fi

# Update page subhead (may be a field like #id_subhead, #id_subtitle, etc.)
if [[ -n "$PAGE_SUBHEAD" ]]; then
    subhead_set="false"
    for subhead_sel in '#id_subhead' '#id_subtitle' '#id_sub_title' '#id_page_subhead'; do
        subhead_exists=$($RODNEY_CMD js "document.querySelector('${subhead_sel}') ? 'yes' : 'no'" 2>/dev/null || echo "no")
        if [[ "$subhead_exists" == "yes" ]]; then
            echo "  Setting page subhead via ${subhead_sel}: ${PAGE_SUBHEAD}"
            rodney_safe_input "$subhead_sel" "$PAGE_SUBHEAD"
            subhead_set="true"
            break
        fi
    done
    # Also try data-contentpath based selector
    if [[ "$subhead_set" == "false" ]]; then
        subhead_exists=$($RODNEY_CMD js "document.querySelector('[data-contentpath=\"subhead\"] input, [data-contentpath=\"subtitle\"] input') ? 'yes' : 'no'" 2>/dev/null || echo "no")
        if [[ "$subhead_exists" == "yes" ]]; then
            sel=$($RODNEY_CMD js "
                (document.querySelector('[data-contentpath=\"subhead\"] input') || document.querySelector('[data-contentpath=\"subtitle\"] input')).name
            " 2>/dev/null || echo "")
            if [[ -n "$sel" ]]; then
                echo "  Setting page subhead via contentpath input: ${PAGE_SUBHEAD}"
                rodney_safe_input "input[name='${sel}']" "$PAGE_SUBHEAD"
                subhead_set="true"
            fi
        fi
    fi
    if [[ "$subhead_set" == "false" ]]; then
        echo "  [info] Page subhead field not found on Content tab. Will check other tabs."
    fi
fi

sleep 1
$RODNEY_CMD waitstable

take_named_screenshot "update-05-basic-fields"

# Switch to Promote tab for slug, SEO title, and search description
echo "  Switching to Promote tab..."
if element_exists "$SEL_TAB_PROMOTE" 2>/dev/null; then
    rodney_cmd click "$SEL_TAB_PROMOTE"
    $RODNEY_CMD waitstable

    # Update slug on Promote tab
    slug_exists=$($RODNEY_CMD js "document.querySelector('${SEL_PAGE_SLUG}') ? 'yes' : 'no'" 2>/dev/null || echo "no")
    if [[ "$slug_exists" == "yes" ]]; then
        current_slug=$($RODNEY_CMD js "document.querySelector('${SEL_PAGE_SLUG}')?.value || ''" 2>/dev/null || echo "")
        echo "  Current slug: ${current_slug}"
        echo "  Desired slug: ${PAGE_SLUG}"
        if [[ "$current_slug" != "$PAGE_SLUG" ]]; then
            rodney_safe_input "$SEL_PAGE_SLUG" "$PAGE_SLUG"
            echo "  Slug updated."
        else
            echo "  Slug already correct, skipping."
        fi
    else
        echo "  [info] Slug field not found on Promote tab."
    fi

    # Update SEO fields
    if [[ -n "$SEO_TITLE" ]]; then
        seo_exists=$($RODNEY_CMD js "document.querySelector('#id_seo_title') ? 'yes' : 'no'" 2>/dev/null || echo "no")
        if [[ "$seo_exists" == "yes" ]]; then
            echo "  Setting SEO title: ${SEO_TITLE}"
            rodney_safe_input '#id_seo_title' "$SEO_TITLE"
        fi
    fi

    if [[ -n "$SEARCH_DESC" ]]; then
        desc_exists=$($RODNEY_CMD js "document.querySelector('#id_search_description') ? 'yes' : 'no'" 2>/dev/null || echo "no")
        if [[ "$desc_exists" == "yes" ]]; then
            echo "  Setting search description..."
            rodney_safe_input '#id_search_description' "$SEARCH_DESC"
        fi
    fi

    take_named_screenshot "update-05-promote-tab"

    # Switch back to Content tab
    if element_exists "$SEL_TAB_CONTENT" 2>/dev/null; then
        rodney_cmd click "$SEL_TAB_CONTENT"
        $RODNEY_CMD waitstable
    fi
else
    echo "  [info] Promote tab not found, skipping slug and SEO fields."
fi

echo "=== Update Step 5 complete ==="
