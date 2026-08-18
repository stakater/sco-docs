#!/usr/bin/env bash
# Capture docs screenshots with browser-runner.
#   ./screenshots/capture.sh            -> every flow
#   ./screenshots/capture.sh resources  -> only flows/resources.yaml
# Config comes from screenshots/config.env, credentials from screenshots/.env
# (see .env.example). .env wins on conflicts. Output -> screenshots/captured/.
#
# A failing flow does not stop the run, so one broken page still leaves the rest
# captured; the exit code is non-zero if any flow failed.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${RUNNER_IMAGE:-ghcr.io/stakater/browser-runner:latest}"
OUT="$DIR/captured"
CONFIG_FILE="$DIR/config.env"
ENV_FILE="$DIR/.env"

# The SCO packs these flows call are not in a published image yet. Point RUNNER_PACKS
# at a browser-runner checkout's src/packs to mount them over the image's copy:
#   RUNNER_PACKS=~/browser-runner/src/packs ./screenshots/capture.sh
PACKS="${RUNNER_PACKS:-}"

if [ ! -f "$ENV_FILE" ]; then
    echo "FAIL: $ENV_FILE not found - copy .env.example and fill in the credentials" >&2
    exit 1
fi

mkdir -p "$OUT"
# The runner writes as pwuser (uid 1000), which does not own the checkout on a CI runner.
chmod 0777 "$OUT"

if [ $# -ge 1 ]; then
    flows="$DIR/flows/$1.yaml"
    if [ ! -f "$flows" ]; then
        echo "FAIL: no such flow: $flows" >&2
        exit 1
    fi
    # Single-flow run: drop only this flow's own outputs, so a partial run cannot
    # leave a stale shot of a later step behind.
    grep -oE 'path: *[A-Za-z0-9._-]+\.png' "$flows" | awk '{print $NF}' \
        | while read -r p; do rm -f "$OUT/$p"; done
else
    flows="$(ls "$DIR"/flows/*.yaml)"
    # Start clean so review never sees stale images from a past run.
    rm -f "$OUT"/*.png
fi

packs_mount=()
if [ -n "$PACKS" ]; then
    packs_mount=(-v "$PACKS:/runner/packs:ro")
    echo "packs: $PACKS (mounted over the image's copy)"
fi

failed=0
for flow in $flows; do
    name="$(basename "$flow" .yaml)"
    echo "RUN: $name"
    if docker run --rm \
        --env-file "$CONFIG_FILE" \
        --env-file "$ENV_FILE" \
        -e E2E_ARTIFACTS_DIR=/out \
        -v "$OUT:/out" \
        "${packs_mount[@]}" \
        -v "$flow:/etc/e2e/test.yaml:ro" \
        "$IMAGE" /etc/e2e/test.yaml; then
        echo "PASS: $name"
    else
        echo "FAIL: $name (exit $?)"
        failed=1
    fi
done

exit $failed
