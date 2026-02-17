#!/usr/bin/env bash
# lib/wagtail-login.sh -- Wagtail admin login flow
# Source after config/env.sh, config/selectors.sh, and lib/rodney-helpers.sh

wagtail_login() {
    echo "=== Logging in to Wagtail admin ==="

    rodney_cmd open "${WAGTAIL_ADMIN_URL}/"
    wait_for_page

    # Check if already logged in (sidebar visible = authenticated)
    if element_exists "$SEL_SIDEBAR"; then
        echo "  Already logged in."
        take_named_screenshot "login-already-authenticated"
        return 0
    fi

    # Fill login form
    echo "  Filling login credentials..."
    rodney_safe_input "$SEL_USERNAME" "$WAGTAIL_USERNAME"
    rodney_safe_input "$SEL_PASSWORD" "$WAGTAIL_PASSWORD"

    take_named_screenshot "login-form-filled"

    # Submit
    rodney_cmd click "$SEL_LOGIN_SUBMIT"
    wait_for_page

    # Verify login succeeded: should NOT still be on login page
    local current_url
    current_url=$($RODNEY_CMD url)
    if [[ "$current_url" == *"/login/"* ]] || [[ "$current_url" == *"/authenticate/"* ]]; then
        echo "  [error] Login failed -- still on login page: $current_url" >&2
        take_named_screenshot "error-login-failed"
        return 1
    fi

    # Double-check sidebar appeared
    if ! element_exists "$SEL_SIDEBAR"; then
        echo "  [warn] Login may have failed -- sidebar not found. Continuing anyway." >&2
    fi

    echo "  Login successful."
    take_named_screenshot "login-success"
    return 0
}
