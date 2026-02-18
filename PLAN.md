# Plan: Update Existing Page Instead of Creating New Child

## Problem Analysis

The current scripts were built around a **"create new child page"** workflow:

1. `create/02-navigate-to-parent.sh` navigates to page ID 11 as a **parent**
2. `create/03-create-page.sh` opens `/admin/pages/add/academics/programpage/11/` — creating a **new child** under page 11
3. Steps 04–12 fill and publish a brand new blank page

**What actually needed to happen:** Page 11 IS the target page — an existing `programpage` that should be **edited in-place** with the new content from `data/design-strategy-mba.json`.

### Key Differences: Create vs Update

| Aspect | Create (current, wrong) | Update (needed) |
|--------|------------------------|-----------------|
| URL | `/admin/pages/add/{app}/{model}/{parent}/` | `/admin/pages/{page_id}/edit/` |
| Form state | Empty form, no blocks | Pre-populated with existing content |
| StreamField | All blocks added fresh | Must inspect existing blocks, update or add |
| Display template | N/A (wasn't handled) | Must set to "flexible template" |
| Page type | Selects type from chooser | Already set (it's an existing page) |

## Implementation Plan

### Step 1: Configuration Changes

**`config/env.sh`** — Add `TARGET_PAGE_ID` variable (the page to edit).

- Add: `TARGET_PAGE_ID` (required) — the page ID to edit (currently 11)
- `PARENT_PAGE_ID` is no longer needed for the update workflow but can remain for reference

**`.claude/hooks/session-start.sh`** — Update `.env` template to include `TARGET_PAGE_ID=11`.

### Step 2: Navigation Library Update

**`lib/wagtail-navigation.sh`** — Add `navigate_to_edit_page()` function:

```bash
navigate_to_edit_page() {
    local page_id="${1:-$TARGET_PAGE_ID}"
    rodney_cmd open "${WAGTAIL_ADMIN_URL}/pages/${page_id}/edit/"
    wait_for_page
}
```

### Step 3: New Discovery Scripts for Existing Page

**`discovery/03-inspect-page-form.sh`** — Modify to navigate to the EDIT form of the target page (not a blank create form). This inspects:

- All form fields (title, slug, display_template, etc.)
- Available tabs
- StreamField containers and their existing blocks

**`discovery/04-inspect-streamfield.sh`** — Modify to discover EXISTING blocks in the body StreamField:

- Count existing blocks
- Identify each block's type (heading, paragraph, quote, embed, etc.)
- Extract current content from each block
- Map block positions/indices

**New: `discovery/06-inspect-display-template.sh`** — Discover the display_template field:

- Find the field (likely a `<select>` or radio group)
- List available options
- Identify which option corresponds to "flexible template"

### Step 4: New StreamField Library Functions

**`lib/streamfield.sh`** — Add functions for working with existing blocks:

```bash
# Get all existing block types and their indices
streamfield_list_blocks(field_contentpath)

# Get the selector for a specific block by index (0-based)
streamfield_get_block_by_index(field_contentpath, index)

# Update content within an existing block (vs adding new)
streamfield_update_field(block_selector, field_name, value)

# Delete an existing block
streamfield_delete_block(block_selector)

# Check if a block of a given type exists
streamfield_has_block_type(field_contentpath, block_type)
```

### Step 5: Rewrite Create Scripts → Update Scripts

**`update/run-all.sh`** — New master runner for the update workflow.

**`update/01-login.sh`** — Same as create/01-login.sh (reuse).

**`update/02-navigate-to-page.sh`** — Navigate to the target page EDIT form:
- Use `navigate_to_edit_page $TARGET_PAGE_ID`
- Verify the edit form loaded
- Screenshot the current state of the form

**`update/03-audit-existing-blocks.sh`** — Audit what's already on the page:
- Count and list all existing StreamField blocks in body
- Record block types and positions
- Output a mapping: "block 0 = heading, block 1 = paragraph, etc."
- This informs which blocks to update vs add

**`update/04-set-display-template.sh`** — Set the display template:
- Find the display_template field (likely in Settings or Content tab)
- Set value to "flexible template"
- Screenshot confirmation

**`update/05-update-basic-fields.sh`** — Update title, slug, SEO fields:
- Similar to create/04 but operating on pre-filled fields
- Clear existing values before setting new ones
- Handle the case where slug may already be correct

**`update/06-update-body-blocks.sh`** — Core logic for updating StreamField body:
- For each section in `data/design-strategy-mba.json`:
  - Check if a corresponding block already exists (match by type/position)
  - If exists: update its content
  - If doesn't exist: add a new block and fill it
- Handle the section-by-section approach from the data file:
  1. Overview (heading + paragraph + embed + paragraph + quote)
  2. Studios & Shops (heading + paragraph + CTA + paragraph + paragraph + CTA)
  3. Faculty (heading + paragraph + CTA)
  4. Curriculum (heading + paragraph + paragraph + quote)
  5. Careers (heading + paragraph + paragraph)
  6. News & Events (heading + paragraph + CTA)
  7. How to Apply (heading + paragraph + CTA)

**`update/07-publish.sh`** — Save and publish:
- Similar to create/12-publish.sh
- Save draft first, then publish

### Step 6: Update Verification Scripts

Modify `verify/` scripts to verify the page was **updated** (not that a new child was created):
- Navigate to page 11's edit form and verify content matches
- Check the published version at the page's existing URL

## Execution Order

1. Run modified discovery to understand the existing page structure
2. Based on discovery output, finalize the block mapping strategy
3. Run the update pipeline
4. Run verification

## Critical Unknowns (to resolve during discovery)

1. **What blocks already exist?** We need discovery to tell us the current block layout before we can determine update vs add strategy.
2. **Display template field location**: Is it a `<select>`, radio buttons, or something else? Which tab is it on?
3. **Block identification**: Can we identify blocks by type alone, or do we need to match by content/position?
4. **Existing content**: Does the page already have partial content we need to preserve, or can we replace everything?
