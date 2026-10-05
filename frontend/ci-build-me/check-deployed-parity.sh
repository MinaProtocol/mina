#!/usr/bin/env bash

# Compare the deployed Cloud Function with the source in this repository.
#
# The function that reads the "!ci-..." comments is deployed by hand (see the
# Deploy part of README.md), so the code that runs can be older than the code
# here, and nothing shows it. This script downloads the source of the deployed
# function and compares it with this directory.
#
# Usage: ./check-deployed-parity.sh [options]
#
#   --project ID       Google Cloud project.  Default: o1labs-192920
#   --region REGION    Region of the function. Default: us-central1
#   --function NAME    Name of the function.  Default: githubWebhookHandler
#   --keep             Keep the downloaded source and write where it is.
#   -h, --help         Write this text.
#
# Exit codes:
#   0  the deployed function is the same as this directory
#   1  the deployed function is different (the difference is written out)
#   2  the comparison could not be made (no gcloud, no permission, ...)
#
# The comparison uses the same files that a deploy sends, that is every file of
# this directory except the ones in .gcloudignore.

set -euo pipefail

PROJECT="o1labs-192920"
REGION="us-central1"
FUNCTION="githubWebhookHandler"
KEEP=0

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

fail() {
    echo "ERROR: $*" >&2
    exit 2
}

while [[ "$#" -gt 0 ]]; do case "$1" in
    --project)  PROJECT="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --function) FUNCTION="$2"; shift 2 ;;
    --keep)     KEEP=1; shift ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 2 ;;
esac; done

# ---------------------------------------------------------------------------
# What the script needs
# ---------------------------------------------------------------------------
for tool in gcloud curl unzip diff python3; do
    command -v "$tool" > /dev/null 2>&1 || fail "'${tool}' is not installed."
done

if ! TOKEN="$(gcloud auth print-access-token 2>/dev/null)" || [[ -z "$TOKEN" ]]; then
    fail "gcloud has no valid credentials. Run 'gcloud auth login' first."
fi

WORK_DIR="$(mktemp -d)"
if [[ "$KEEP" -eq 0 ]]; then
    trap 'rm -rf "$WORK_DIR"' EXIT
fi

# ---------------------------------------------------------------------------
# Where the deployed source is
#
# A generation 1 function gives a download address only through the API method
# generateDownloadUrl, which gcloud does not have a command for. A generation 2
# function holds its source in a Cloud Storage object, which is named in the
# description.
# ---------------------------------------------------------------------------
API_NAME="projects/${PROJECT}/locations/${REGION}/functions/${FUNCTION}"

echo "Reading the description of ${FUNCTION} (${PROJECT}, ${REGION})"

DESCRIBE_JSON="${WORK_DIR}/describe.json"

# Ask for one generation and report the HTTP code, so that "no permission" and
# "no such function" do not look the same.
describe_with() {
    curl -s -o "$DESCRIBE_JSON" -w '%{http_code}' \
        -H "Authorization: Bearer ${TOKEN}" \
        "https://cloudfunctions.googleapis.com/${1}/${API_NAME}"
}

CODE_V1="$(describe_with v1)"
if [[ "$CODE_V1" == "200" ]]; then
    GENERATION=1
else
    CODE_V2="$(describe_with v2)"
    if [[ "$CODE_V2" == "200" ]]; then
        GENERATION=2
    else
        case "$CODE_V1" in
            401)
                fail "the credentials of gcloud are not valid any more (HTTP 401).
       Run:  gcloud auth login" ;;
            403)
                fail "this account may not read the function (HTTP 403).
       Ask for the role roles/cloudfunctions.viewer on ${PROJECT}." ;;
            404)
                fail "no function '${FUNCTION}' in ${PROJECT}/${REGION} (HTTP 404).
       Give another name with --function or another region with --region." ;;
            *)
                fail "cannot read the function (HTTP ${CODE_V1} for v1, ${CODE_V2} for v2).
       $(head -c 300 "$DESCRIBE_JSON")" ;;
        esac
    fi
fi

UPDATE_TIME="$(python3 -c "
import json,sys
d=json.load(open('${DESCRIBE_JSON}'))
print(d.get('updateTime') or d.get('updateTime','(unknown)'))
")"
echo "  generation : ${GENERATION}"
echo "  updated    : ${UPDATE_TIME}"

ZIP="${WORK_DIR}/deployed.zip"

if [[ "$GENERATION" -eq 1 ]]; then
    DOWNLOAD_URL="$(curl -sf -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "https://cloudfunctions.googleapis.com/v1/${API_NAME}:generateDownloadUrl" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("downloadUrl",""))')"

    [[ -n "$DOWNLOAD_URL" ]] || fail "the API gave no download address for the source."
    curl -sf "$DOWNLOAD_URL" -o "$ZIP" || fail "cannot download the source archive."
else
    STORAGE="$(python3 -c "
import json
d=json.load(open('${DESCRIBE_JSON}'))
s=((d.get('buildConfig') or {}).get('source') or {}).get('storageSource') or {}
if s.get('bucket') and s.get('object'):
    print('gs://%s/%s' % (s['bucket'], s['object']))
")"
    [[ -n "$STORAGE" ]] || fail "the description names no source object."
    echo "  source     : ${STORAGE}"
    gcloud storage cp "$STORAGE" "$ZIP" > /dev/null 2>&1 \
        || fail "cannot download ${STORAGE}."
fi

# ---------------------------------------------------------------------------
# Compare
# ---------------------------------------------------------------------------
DEPLOYED_DIR="${WORK_DIR}/deployed"
mkdir -p "$DEPLOYED_DIR"
unzip -q "$ZIP" -d "$DEPLOYED_DIR" || fail "cannot open the source archive."

# A deploy sends every file except the ones in .gcloudignore. Use the same list,
# so that a file which is never sent is not reported as a difference.
EXCLUDES=(-x '.git' -x '.gitignore' -x '.gcloudignore' -x 'node_modules')
if [[ -f "${SOURCE_DIR}/.gcloudignore" ]]; then
    EXCLUDES=()
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | tr -d '[:space:]')"
        [[ -n "$line" ]] && EXCLUDES+=(-x "$line")
    done < "${SOURCE_DIR}/.gcloudignore"
fi
# This script is itself not part of the function.
EXCLUDES+=(-x "$(basename "${BASH_SOURCE[0]}")")

DIFF_OUT="${WORK_DIR}/diff.txt"
set +e
diff -ru "${EXCLUDES[@]}" "$DEPLOYED_DIR" "$SOURCE_DIR" > "$DIFF_OUT" 2>&1
DIFF_STATUS=$?
set -e

if [[ "$KEEP" -eq 1 ]]; then
    echo "  downloaded source kept in ${DEPLOYED_DIR}"
fi

if [[ "$DIFF_STATUS" -eq 0 ]]; then
    echo ""
    echo "✅ The deployed function is the same as ${SOURCE_DIR}."
    exit 0
fi

echo ""
echo "❌ The deployed function is NOT the same as this directory."
echo "   left  = deployed (${UPDATE_TIME})"
echo "   right = ${SOURCE_DIR}"
echo ""
cat "$DIFF_OUT"
echo ""
echo "Deploy the current source with the command in README.md to remove the difference."
exit 1
