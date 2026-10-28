#!/bin/bash

# Check arguments
if (( $# != 1 )); then
    printf 'ERROR: Usage: %s <file>\n' "$0" >&2
    exit 1
fi

FILE="$1"

# Check the file
if [[ ! -f "$FILE" || ! -r "$FILE" ]]; then
    printf 'ERROR: File does not exist or is not readable: %s\n' "$FILE" >&2
    exit 1
fi

# Check dependencies
for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'ERROR: Missing dependency: %s\n' "$cmd" >&2
        exit 1
    fi
done

# Upload directly to GoFile
printf 'Uploading: %s\n' "$FILE"

if ! RESPONSE=$(curl \
    --fail-with-body \
    --silent \
    --show-error \
    --progress-bar \
    -F "file=@${FILE}" \
    "https://upload.gofile.io/uploadfile"); then

    printf '\nERROR: Upload request failed.\n' >&2
    [[ -n "${RESPONSE:-}" ]] && printf '%s\n' "$RESPONSE" >&2
    exit 1
fi

# Extract the download link
if ! LINK=$(jq -er \
    'select(.status == "ok") | .data.downloadPage // empty' \
    <<< "$RESPONSE"); then

    printf 'ERROR: Could not extract download link.\n' >&2
    printf '%s\n' "$RESPONSE" >&2
    exit 1
fi

# Print the link
printf '\n%s\n' "$LINK"
