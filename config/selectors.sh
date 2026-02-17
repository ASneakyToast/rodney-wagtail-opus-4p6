#!/usr/bin/env bash
# config/selectors.sh -- CSS selectors for Wagtail 6.x admin
# Known defaults are pre-filled. Blanks are populated by discovery/05-generate-selectors.sh.

# --- Login page ---
SEL_USERNAME='#id_username'
SEL_PASSWORD='#id_password'
SEL_LOGIN_SUBMIT='button[type="submit"]'

# --- Dashboard / sidebar ---
SEL_SIDEBAR='.sidebar-menu-item'

# --- Page explorer ---
SEL_ADD_CHILD_PAGE='a[href*="add_subpage"]'
SEL_PAGE_LISTING='.listing tbody'

# --- Page type selection (populated by discovery) ---
SEL_PAGE_TYPE_LINK=''

# --- Page edit form ---
SEL_PAGE_TITLE='#id_title'
SEL_PAGE_SLUG='#id_slug'
SEL_EDIT_FORM='#page-edit-form'

# --- Action buttons ---
SEL_ACTION_PUBLISH='.action-save [name="action-publish"]'
SEL_ACTION_DRAFT='.action-save [name="action-draft"]'
SEL_ACTION_MENU_TOGGLE='.dropdown-toggle'

# --- Success messages ---
SEL_SUCCESS_MESSAGE='.messages .success'

# --- StreamField (populated by discovery) ---
SEL_STREAMFIELD_BODY='[data-contentpath="body"]'
SEL_ADD_BLOCK_BUTTON=''
SEL_BLOCK_CHOOSER=''

# --- Tabs ---
SEL_TAB_CONTENT='a[href="#tab-content"]'
SEL_TAB_PROMOTE='a[href="#tab-promote"]'
SEL_TAB_SETTINGS='a[href="#tab-settings"]'

# --- Draftail ---
SEL_DRAFTAIL_EDITOR='.Draftail-Editor'
SEL_DRAFTAIL_INPUT='input[type="hidden"]'
