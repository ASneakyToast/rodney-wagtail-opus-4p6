#!/usr/bin/env bash
# lib/rodney-helpers.sh -- Reusable Rodney wrapper functions
# Source this file in scripts: source "$(dirname "$0")/../lib/rodney-helpers.sh"

# Requires RODNEY_CMD and SCREENSHOT_DIR from config/env.sh

# Run a rodney command with logging
rodney_cmd() {
    local cmd_desc="$*"
    echo "  [rodney] $cmd_desc"
    $RODNEY_CMD "$@"
}

# Retry a rodney command up to N times with exponential backoff
rodney_retry() {
    local max_attempts="${1:-3}"
    shift
    local delay=2

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        if $RODNEY_CMD "$@"; then
            return 0
        fi
        if ((attempt < max_attempts)); then
            echo "  [retry] Attempt $attempt/$max_attempts failed, waiting ${delay}s..." >&2
            $RODNEY_CMD sleep "$delay" 2>/dev/null || sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    echo "  [error] Command failed after $max_attempts attempts: rodney $*" >&2
    take_named_screenshot "error-retry-exhausted"
    return 1
}

# Wait for a selector, then click it
rodney_wait_and_click() {
    local selector="$1"
    rodney_cmd wait "$selector"
    rodney_cmd waitstable
    rodney_cmd click "$selector"
}

# Clear a field, input text, and verify the value took
rodney_safe_input() {
    local selector="$1"
    local text="$2"

    rodney_cmd wait "$selector"
    rodney_cmd clear "$selector"
    rodney_cmd input "$selector" "$text"

    # Verify the value was set correctly (skip if selector has JS-unfriendly chars)
    local actual
    local escaped_sel
    escaped_sel=$(printf '%s' "$selector" | sed "s/'/\\\\'/g")
    actual=$($RODNEY_CMD js "document.querySelector('${escaped_sel}')?.value || ''" 2>/dev/null || echo "")
    if [[ -n "$actual" ]] && [[ "$actual" != "$text" ]]; then
        echo "  [warn] Field $selector: expected '${text:0:40}...' but got '${actual:0:40}...'" >&2
        # Retry once: clear and re-input
        rodney_cmd clear "$selector"
        rodney_cmd input "$selector" "$text"
    fi
}

# Take a screenshot with a descriptive name
take_named_screenshot() {
    local step_name="$1"
    local filename="${SCREENSHOT_DIR}/$(date +%Y%m%d-%H%M%S)-${step_name}.png"
    $RODNEY_CMD screenshot "$filename"
    echo "  [screenshot] $filename"
    echo "$filename"
}

# Start a local auth proxy that relays to the upstream egress proxy with JWT creds.
# Required when Chrome cannot embed proxy credentials directly.
_start_auth_proxy() {
    # Skip if already running
    if [[ -n "${_AUTH_PROXY_PID:-}" ]] && kill -0 "$_AUTH_PROXY_PID" 2>/dev/null; then
        return 0
    fi

    local proxy_url="${HTTPS_PROXY:-${HTTP_PROXY:-}}"
    [[ -z "$proxy_url" ]] && return 0  # no proxy configured

    # Parse upstream host/port from proxy URL
    local upstream_host upstream_port
    upstream_host=$(echo "$proxy_url" | sed -E 's|.*@([^:]+):([0-9]+).*|\1|')
    upstream_port=$(echo "$proxy_url" | sed -E 's|.*@([^:]+):([0-9]+).*|\2|')

    [[ -z "$upstream_host" || -z "$upstream_port" ]] && return 0

    # Extract user:pass from proxy URL for Basic auth
    local proxy_userinfo
    proxy_userinfo=$(echo "$proxy_url" | sed -E 's|https?://([^@]+)@.*|\1|')

    node -e "
const http = require('http'), net = require('net');
const UH = '$upstream_host', UP = $upstream_port;
const auth = Buffer.from(decodeURIComponent('$proxy_userinfo'.split(':')[0]) + ':' + decodeURIComponent('$proxy_userinfo'.split(':').slice(1).join(':'))).toString('base64');
const srv = http.createServer((req, res) => {
  const pr = http.request({host:UH,port:UP,method:req.method,path:req.url,headers:{...req.headers,'Proxy-Authorization':'Basic '+auth}}, p => { res.writeHead(p.statusCode,p.headers); p.pipe(res); });
  req.pipe(pr); pr.on('error', e => { res.writeHead(502); res.end(); });
});
srv.on('connect',(req,clt,head) => {
  const s = net.connect(UP,UH,()=>{ s.write('CONNECT '+req.url+' HTTP/1.1\r\nHost: '+req.url+'\r\nProxy-Authorization: Basic '+auth+'\r\n\r\n'); });
  s.once('data',d => { if(d.toString().includes('200')){clt.write('HTTP/1.1 200 Connection Established\r\n\r\n');s.write(head);s.pipe(clt);clt.pipe(s);}else{clt.end();s.end();}});
  s.on('error',()=>{clt.end();});
});
srv.listen(18080,'127.0.0.1',()=>console.log('auth-proxy:18080'));
" &>/dev/null &
    _AUTH_PROXY_PID=$!
    sleep 2
    echo "  [rodney] Auth proxy started (PID $_AUTH_PROXY_PID, port 18080)"
}

# Start rodney if not already running
ensure_browser() {
    # Check if browser is actually connected (status exits 0 even when no session)
    local status_out
    status_out=$($RODNEY_CMD status 2>&1 || true)
    if echo "$status_out" | grep -qi "connected\|active\|running" && ! echo "$status_out" | grep -qi "no active"; then
        echo "  [rodney] Browser already running."
    else
        echo "  [rodney] Starting browser..."

        # Start auth proxy if behind an egress proxy with embedded credentials
        _start_auth_proxy

        local CHROME_BIN
        CHROME_BIN=$(command -v google-chrome 2>/dev/null \
                  || command -v chromium 2>/dev/null \
                  || command -v chromium-browser 2>/dev/null \
                  || echo "/root/.cache/ms-playwright/chromium-1194/chrome-linux/chrome")

        local connect_flag=""
        [[ "${RODNEY_LOCAL:-false}" == "true" ]] && connect_flag="--local"

        # Try rodney start first
        if $RODNEY_CMD start $connect_flag 2>/dev/null; then
            sleep 2
            return 0
        fi

        echo "  [rodney] rodney start failed, launching Chrome manually..."

        # Build Chrome flags
        local chrome_flags=(
            --headless --no-sandbox --disable-gpu
            --remote-debugging-port=9222
            --disable-dev-shm-usage
            --no-first-run --disable-default-apps
            --user-data-dir=/tmp/rodney-chrome-profile
        )

        # Route through local auth proxy if it's running
        if [[ -n "${_AUTH_PROXY_PID:-}" ]] && kill -0 "$_AUTH_PROXY_PID" 2>/dev/null; then
            chrome_flags+=(--proxy-server="http://127.0.0.1:18080" --ignore-certificate-errors)
        fi

        "$CHROME_BIN" "${chrome_flags[@]}" &>/dev/null &
        sleep 4

        $RODNEY_CMD connect localhost:9222 $connect_flag
        sleep 2
    fi
}

# Assert current URL contains a substring
check_url_contains() {
    local expected="$1"
    local current_url
    current_url=$($RODNEY_CMD url)
    if [[ "$current_url" != *"$expected"* ]]; then
        echo "  [error] Expected URL to contain '$expected', but at: $current_url" >&2
        take_named_screenshot "error-wrong-url"
        return 1
    fi
}

# Wait for page to fully settle (load + DOM stable + network idle)
wait_for_page() {
    $RODNEY_CMD waitload 2>/dev/null || true
    $RODNEY_CMD waitstable
    $RODNEY_CMD waitidle 2>/dev/null || true
}

# Extract text content, returning empty string on failure instead of erroring
safe_text() {
    local selector="$1"
    $RODNEY_CMD text "$selector" 2>/dev/null || echo ""
}

# Check if element exists (returns 0/1 exit code)
element_exists() {
    local selector="$1"
    $RODNEY_CMD exists "$selector" 2>/dev/null
}
