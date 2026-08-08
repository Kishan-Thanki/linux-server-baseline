#!/usr/bin/env bash
set -euo pipefail

SERVICE=""
VERSION=""
URL=""
ARTIFACT=""
SYSTEMD_SERVICE=""
HEALTH_URL=""
EXPECTED_SHA256=""

########################################################
# Runtime State
########################################################
PREVIOUS_RELEASE=""
DEPLOYMENT_FAILED=0
FAILURE_REASON=""
DEPLOYMENT_STAGE=""
DEPLOYMENT_RESULT=""
KEEP_RELEASES=2
DEPLOYMENT_LOG="/var/log/platform/deployments.log"
ARTIFACT_DOWNLOADED=0  

########################################################
# Functions
########################################################
cleanup() {
    if [[ -n "${LOCK_FILE:-}" && -d "${LOCK_FILE:-}" ]]; then
        sudo -n rm -rf "$LOCK_FILE" 2>/dev/null || true
    fi

    if [[ "${ARTIFACT_DOWNLOADED:-0}" -eq 1 && -n "${ARTIFACT:-}" && -f "${ARTIFACT:-}" ]]; then
        rm -f -- "$ARTIFACT"
    fi
}

deployment_stage() {
    DEPLOYMENT_STAGE="$1"
    echo
    echo "=================================================="
    echo "Stage : $DEPLOYMENT_STAGE"
    echo "=================================================="
}

deployment_result() {
    DEPLOYMENT_RESULT="$1"
}

# Append to FAILURE_REASON without leaving a leading "; " when it was empty.
append_failure_reason() {
    if [[ -z "$FAILURE_REASON" ]]; then
        FAILURE_REASON="$1"
    else
        FAILURE_REASON="${FAILURE_REASON}; $1"
    fi
}

rollback() {
    if [[ -z "$PREVIOUS_RELEASE" ]]; then
        echo "No previous release available."
        append_failure_reason "rollback not possible: no previous release"
        return 1
    fi

    if [[ ! -d "$PREVIOUS_RELEASE" ]]; then
        echo "Previous release no longer exists on disk:"
        echo "  $PREVIOUS_RELEASE"
        append_failure_reason "rollback not possible: previous release missing on disk"
        return 1
    fi

    echo "Rolling back to:"
    echo "  $PREVIOUS_RELEASE"

    if ! sudo ln -sfn "$PREVIOUS_RELEASE" "$CURRENT"; then
        append_failure_reason "rollback failed: could not update symlink"
        return 1
    fi

    if [[ -n "$SYSTEMD_SERVICE" ]]; then
        if ! sudo systemctl restart "$SYSTEMD_SERVICE"; then
            append_failure_reason "rollback failed: service restart failed"
            return 1
        fi
    fi

    return 0
}

rollback_health_check() {
    [[ -n "$HEALTH_URL" ]] || return 0
    echo "Validating rollback..."
    sleep 3
    set +e
    STATUS=$(
        curl \
            --silent \
            --output /dev/null \
            --write-out "%{http_code}" \
            --max-time 5 \
            "$HEALTH_URL"
    )
    CURL_EXIT=$?
    set -e
    if [[ $CURL_EXIT -eq 0 && "$STATUS" == "200" ]]; then
        return 0
    fi
    if [[ $CURL_EXIT -ne 0 ]]; then
        append_failure_reason "rollback health check failed: connection error"
    else
        append_failure_reason "rollback health check failed: HTTP $STATUS"
    fi
    return 1
}

prune_old_releases() {
    echo "Pruning old releases..."
    mapfile -t releases < <(
        find "$BASE" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf "%T@ %p\n" \
        | sort -n \
        | cut -d' ' -f2-
    )

    total=${#releases[@]}
    if (( total <= KEEP_RELEASES )); then
        echo "Nothing to prune."
        return 0
    fi

    # Filter out protected entries first -- the one just deployed, the one
    # rollback would need, and (defensively) anything named "current" --
    # so a protected release doesn't eat a removal slot without being
    # replaced by the next-oldest actually-prunable one.
    prunable=()
    for r in "${releases[@]}"; do
        if [[ "$(basename "$r")" == "current" || "$r" == "$RELEASE" || "$r" == "$PREVIOUS_RELEASE" ]]; then
            continue
        fi
        prunable+=("$r")
    done

    remove_count=$((total - KEEP_RELEASES))
    if (( remove_count > ${#prunable[@]} )); then
        remove_count=${#prunable[@]}
    fi

    for ((i=0; i<remove_count; i++)); do
        old="${prunable[$i]}"
        echo "Removing $old"
        sudo rm -rf "$old"
    done
}

log_deployment() {
    sudo mkdir -p "$(dirname "$DEPLOYMENT_LOG")"
    printf '%s service=%s version=%s result=%s stage=%s reason="%s"\n' \
        "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        "$SERVICE" \
        "$VERSION" \
        "$DEPLOYMENT_RESULT" \
        "$DEPLOYMENT_STAGE" \
        "${FAILURE_REASON:-}" \
    | sudo tee -a "$DEPLOYMENT_LOG" >/dev/null
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --service)
            SERVICE="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --url)
            URL="$2"
            shift 2
            ;;
        --artifact)
            ARTIFACT="$2"
            shift 2
            ;;
        --sha256)
            EXPECTED_SHA256="$2"
            shift 2
            ;;
        --systemd)
            SYSTEMD_SERVICE="$2"
            shift 2
            ;;
        --health)
            HEALTH_URL="$2"
            shift 2
            ;;
        *)
            deployment_result "FAILED"
            FAILURE_REASON="Unknown argument: $1"
            echo "Unknown argument: $1"
            log_deployment
            exit 1
            ;;
    esac
done

########################################################
# 1. Validate
########################################################
deployment_stage "VALIDATE"
[[ -n "$SERVICE" ]] || { deployment_result "FAILED"; FAILURE_REASON="Missing --service"; echo "Missing --service"; log_deployment; exit 1; }
[[ -n "$VERSION" ]] || { deployment_result "FAILED"; FAILURE_REASON="Missing --version"; echo "Missing --version"; log_deployment; exit 1; }

# SERVICE and VERSION are used unsanitized in sudo mkdir/tar/ln paths below --
# reject anything that isn't a plain identifier so "--version ../../etc" etc.
# can't escape BASE.
SAFE_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
[[ "$SERVICE" =~ $SAFE_NAME_RE ]] || { deployment_result "FAILED"; FAILURE_REASON="Invalid --service value"; echo "Invalid --service value: $SERVICE"; log_deployment; exit 1; }
[[ "$VERSION" =~ $SAFE_NAME_RE ]] || { deployment_result "FAILED"; FAILURE_REASON="Invalid --version value"; echo "Invalid --version value: $VERSION"; log_deployment; exit 1; }

########################################################
# 2. Download
########################################################
deployment_stage "DOWNLOAD"
if [[ -n "$URL" ]]; then
    # mktemp both avoids a fixed, guessable filename and sidesteps a same-
    # service+version collision in the window before the lock is acquired.
    ARTIFACT=$(mktemp "/tmp/${SERVICE}-${VERSION}-XXXXXX.tar.gz")
    # Set this as soon as the temp file exists, not after a successful
    # download -- if curl fails we still created this file and still own it.
    ARTIFACT_DOWNLOADED=1
    echo "Downloading artifact..."
    if ! curl \
        --fail \
        --location \
        --silent \
        --show-error \
        "$URL" \
        --output "$ARTIFACT"; then
        deployment_result "FAILED"
        FAILURE_REASON="Artifact download failed"
        log_deployment
        exit 1
    fi
    echo "Download complete."
fi

########################################################
# 3. Verify
########################################################
deployment_stage "VERIFY"
[[ -n "$ARTIFACT" ]] || {
    deployment_result "FAILED"
    FAILURE_REASON="Missing --artifact or --url"
    echo "Missing --artifact or --url"
    log_deployment
    exit 1
}
[[ -f "$ARTIFACT" ]] || {
    echo "Artifact not found: $ARTIFACT"
    deployment_result "FAILED"
    FAILURE_REASON="Artifact missing"
    log_deployment
    exit 1
}

if [[ -n "$EXPECTED_SHA256" ]]; then
    ACTUAL_SHA256=$(sha256sum "$ARTIFACT" | awk '{print $1}') || {
        deployment_result "FAILED"
        FAILURE_REASON="Unable to calculate SHA256"
        log_deployment
        exit 1
    }
    if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
        echo "SHA256 checksum mismatch."
        echo "  Expected: $EXPECTED_SHA256"
        echo "  Actual:   $ACTUAL_SHA256"
        deployment_result "FAILED"
        FAILURE_REASON="Checksum mismatch (expected ${EXPECTED_SHA256}, got ${ACTUAL_SHA256})"
        log_deployment
        exit 1
    fi
    echo "SHA256 verified."
fi

########################################################
# 4. Paths
########################################################
########################################################
# Release Paths
########################################################
BASE="/opt/platform/releases/${SERVICE}"
RELEASE="${BASE}/${VERSION}"
CURRENT="${BASE}/current"

########################################################
# Lock Paths
########################################################
LOCK_DIR="/var/lock/platform"
LOCK_FILE="${LOCK_DIR}/${SERVICE}.lock"

########################################################
# Acquire Deployment Lock (Atomic Directory Lock)
########################################################
deployment_stage "LOCK"
echo "Acquiring deployment lock..."

if ! sudo mkdir -p "$LOCK_DIR"; then
    deployment_result "FAILED"
    FAILURE_REASON="Unable to create lock directory"
    log_deployment
    exit 1
fi

if ! sudo mkdir "$LOCK_FILE" 2>/dev/null; then
    deployment_result "FAILED"
    FAILURE_REASON="Deployment already running"
    echo
    echo "Another deployment is already running."
    echo "Lock Path: $LOCK_FILE"
    log_deployment
    exit 1
fi
echo "Deployment lock acquired."

########################################################
# 5. Resolve deployment state
########################################################
deployment_stage "RESOLVE"
if [[ -L "$CURRENT" ]]; then
    PREVIOUS_RELEASE=$(readlink -f "$CURRENT")
    echo "Current release detected:"
    echo "  $PREVIOUS_RELEASE"
else
    echo "No current release found."
fi

########################################################
# 6. Extract
########################################################
deployment_stage "EXTRACT"
echo "Creating release directory..."
if [[ -e "$RELEASE" ]]; then
    deployment_result "FAILED"
    FAILURE_REASON="Release already exists"
    echo "Release already exists:"
    echo "  $RELEASE"
    log_deployment
    exit 1
fi
if ! sudo mkdir -p "$RELEASE"; then
    deployment_result "FAILED"
    FAILURE_REASON="Unable to create release directory"
    log_deployment
    exit 1
fi

echo "Extracting artifact..."
if ! sudo tar -xzf "$ARTIFACT" -C "$RELEASE"; then
    deployment_result "FAILED"
    FAILURE_REASON="Extraction failed"
    # Don't leave a half-extracted dir behind -- it would block the next
    # retry of this exact version with "Release already exists".
    sudo rm -rf "$RELEASE"
    log_deployment
    exit 1
fi

# Distinguish "extracted but genuinely empty" from "couldn't inspect it"
# (e.g. permissions problem on the release dir).
set +e
FIND_OUTPUT=$(sudo find "$RELEASE" -mindepth 1 -maxdepth 1 -print -quit 2>&1)
FIND_EXIT=$?
set -e

if [[ $FIND_EXIT -ne 0 ]]; then
    deployment_result "FAILED"
    FAILURE_REASON="Unable to inspect extracted release: ${FIND_OUTPUT}"
    echo "Unable to inspect extracted release."
    sudo rm -rf "$RELEASE"
    log_deployment
    exit 1
fi

if [[ -z "$FIND_OUTPUT" ]]; then
    deployment_result "FAILED"
    FAILURE_REASON="Empty release"
    echo "Extraction produced an empty release."
    sudo rm -rf "$RELEASE"
    log_deployment
    exit 1
fi

########################################################
# 7. Activate
########################################################
deployment_stage "ACTIVATE"
echo "Updating current symlink..."
if ! sudo ln -sfn "$RELEASE" "$CURRENT"; then
    deployment_result "FAILED"
    FAILURE_REASON="Failed to update current symlink"
    log_deployment
    exit 1
fi

########################################################
# 8. Restart
########################################################
deployment_stage "RESTART"
if [[ -n "$SYSTEMD_SERVICE" ]]; then
    echo "Restarting systemd service..."
    set +e
    sudo systemctl restart "$SYSTEMD_SERVICE"
    RESTART_EXIT=$?
    set -e
    if [[ $RESTART_EXIT -ne 0 ]]; then
        echo "Service restart failed."
        DEPLOYMENT_FAILED=1
        append_failure_reason "Service restart failed"
    else
        echo "Systemd restarted."
    fi
fi

########################################################
# 9. Validation
########################################################
deployment_stage "VALIDATION"
if [[ $DEPLOYMENT_FAILED -eq 0 && -n "$HEALTH_URL" ]]; then
    echo "Waiting before validation..."
    sleep 3
    echo "Running validation..."
    set +e
    STATUS=$(
        curl \
            --silent \
            --output /dev/null \
            --write-out "%{http_code}" \
            --max-time 5 \
            "$HEALTH_URL"
    )
    CURL_EXIT=$?
    set -e
    if [[ $CURL_EXIT -ne 0 ]]; then
        echo "Validation failed (connection error)"
        DEPLOYMENT_FAILED=1
        append_failure_reason "Connection error"
    elif [[ "$STATUS" != "200" ]]; then
        echo "Validation failed (HTTP $STATUS)"
        DEPLOYMENT_FAILED=1
        append_failure_reason "HTTP $STATUS"
    else
        echo "Validation passed."
    fi
fi

########################################################
# 10. Recovery
########################################################
if [[ $DEPLOYMENT_FAILED -eq 1 ]]; then
    deployment_stage "RECOVERY"
    echo
    echo "Deployment entered recovery phase."
    echo "Reason: $FAILURE_REASON"
    if rollback; then
        if rollback_health_check; then
            echo "Rollback completed successfully."
            deployment_result "ROLLED_BACK"
        else
            echo "Rollback completed, but validation failed."
            deployment_result "ROLLBACK_FAILED"
        fi
    else
        echo "Rollback failed."
        deployment_result "FAILED"
    fi
    log_deployment
    exit 1
fi

deployment_stage "PRUNE"
prune_old_releases

########################################################
# 11. Summary
########################################################
deployment_stage "SUMMARY"
deployment_result "SUCCESS"

printf "\nDeployment completed successfully.\n\n"
printf "%-18s %s\n" "Service:" "$SERVICE"
printf "%-18s %s\n" "Version:" "$VERSION"
printf "%-18s %s\n" "Artifact:" "$ARTIFACT"
printf "%-18s %s\n" "Release:" "$RELEASE"
printf "%-18s %s\n" "Current:" "$CURRENT"
printf "%-18s %s\n" "Result:" "$DEPLOYMENT_RESULT"

if [[ -n "$PREVIOUS_RELEASE" ]]; then
    printf "%-18s %s\n" "Previous:" "$PREVIOUS_RELEASE"
fi
if [[ -n "$SYSTEMD_SERVICE" ]]; then
    printf "%-18s %s\n" "Systemd:" "$SYSTEMD_SERVICE"
fi
if [[ -n "$HEALTH_URL" ]]; then
    printf "%-18s %s\n" "Validation:" "$HEALTH_URL"
fi

log_deployment