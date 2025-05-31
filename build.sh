#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh

TASK_STATUS=1  # Default to failure

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "🔧 Working inside [$CODEBASE_LOCATION]"
sleep "$SLEEP_DURATION"
cd "${CODEBASE_LOCATION}" || { logErrorMessage "❌ Failed to change directory"; exit 1; }

# Inputs with defaults
# SOURCE_PATH="${SOURCE_PATH:-"./data"}"
# TARGET_FILENAME="${TARGET_FILENAME:-"artifact"}"
ARCHIVE_FORMAT="${ARCHIVE_FORMAT:-"zip"}"   # zip or tar.gz

# Required validation
[[ -z "$ARTIFACTORY_URL" ]] && { echo "❌ ARTIFACTORY_URL is missing"; exit 1; }
[[ -z "$ARTIFACTORY_REPO_PATH" ]] && { echo "❌ ARTIFACTORY_REPO_PATH is missing"; exit 1; }
[[ -z "$JFROG_USER" ]] && { echo "❌ JFROG_USER is missing"; exit 1; }

if [[ -z "$JFROG_API_KEY" && -z "$JFROG_PASSWORD" ]]; then
  logErrorMessage "❌ Must provide either JFROG_API_KEY or JFROG_PASSWORD"
  exit 1
  TASK_STATUS=$?
fi

if [[ ! -e "$SOURCE_PATH" ]]; then
  logErrorMessage "❌ SOURCE_PATH '$SOURCE_PATH' does not exist"
  exit 1
  TASK_STATUS=$?
fi

# Archive extension
EXT=""
case "$ARCHIVE_FORMAT" in
  zip) EXT="zip" ;;
  tar.gz) EXT="tar.gz" ;;
  *)
    logErrorMessage "❌ Unsupported archive format: $ARCHIVE_FORMAT"
    exit 1
    TASK_STATUS=$?
    ;;
esac

ARCHIVE_FILE="/tmp/${TARGET_FILENAME}.${EXT}"

# Archive creation
logInfoMessage "📦 Creating $ARCHIVE_FORMAT archive from '$SOURCE_PATH' → $ARCHIVE_FILE"
if [[ "$ARCHIVE_FORMAT" == "zip" ]]; then
  if [[ -f "$SOURCE_PATH" ]]; then
    zip -j "$ARCHIVE_FILE" "$SOURCE_PATH"
  else
    zip -r "$ARCHIVE_FILE" "$SOURCE_PATH"
  fi
else
  tar -czf "$ARCHIVE_FILE" -C "$(dirname "$SOURCE_PATH")" "$(basename "$SOURCE_PATH")"
fi

if [[ ! -f "$ARCHIVE_FILE" ]]; then
  logErrorMessage "❌ Archive creation failed"
  exit 1
  TASK_STATUS=$?
fi

# Configure JFrog CLI
logInfoMessage "🔐 Configuring JFrog CLI for upload..."
if [[ -n "$JFROG_API_KEY" ]]; then
  jf config add temp-server \
    --artifactory-url="$ARTIFACTORY_URL" \
    --user="$JFROG_USER" \
    --password="$JFROG_API_KEY" \
    --interactive=false
else
  jf config add temp-server \
    --artifactory-url="$ARTIFACTORY_URL" \
    --user="$JFROG_USER" \
    --password="$JFROG_PASSWORD" \
    --interactive=false
fi

# Upload
UPLOAD_PATH="$ARTIFACTORY_REPO_PATH/$(basename "$ARCHIVE_FILE")"
logInfoMessage "🚀 Uploading $ARCHIVE_FILE to $UPLOAD_PATH"
UPLOAD_OUTPUT=$(jf rt u "$ARCHIVE_FILE" "$UPLOAD_PATH" --server-id=temp-server 2>&1)

UPLOAD_EXIT_CODE=$?

if [[ $UPLOAD_EXIT_CODE -ne 0 ]]; then
  logErrorMessage "❌ Upload to Artifactory failed"

  # Try to extract status and message from JSON error (from 'errors' array)
  STATUS=$(echo "$UPLOAD_OUTPUT" | grep -o '"status": *[0-9]*' | head -1 | grep -o '[0-9]*')
  MESSAGE=$(echo "$UPLOAD_OUTPUT" | grep -o '"message": *"[^"]*"' | head -1 | sed 's/.*"message": *"\([^"]*\)".*/\1/')

  # Check for "blocked due to recurrent login failures" and extract wait time
  if [[ "$MESSAGE" =~ blocked\ due\ to\ recurrent\ login\ failures ]]; then
    WAIT_SECONDS=$(echo "$MESSAGE" | grep -o '[0-9]\+ seconds' | grep -o '[0-9]\+')
    if [[ -n "$WAIT_SECONDS" ]]; then
      echo -e "\033[1;33m[WARN]\033[0m $MESSAGE"
      echo -e "\033[1;33m[INFO]\033[0m Retrying after $WAIT_SECONDS seconds..."
      sleep "$WAIT_SECONDS"
      # Retry upload once
      UPLOAD_OUTPUT=$(jf rt u "$ARCHIVE_FILE" "$UPLOAD_PATH" --server-id=temp-server 2>&1)
      UPLOAD_EXIT_CODE=$?
      STATUS=$(echo "$UPLOAD_OUTPUT" | grep -o '"status": *[0-9]*' | head -1 | grep -o '[0-9]*')
      MESSAGE=$(echo "$UPLOAD_OUTPUT" | grep -o '"message": *"[^"]*"' | head -1 | sed 's/.*"message": *"\([^"]*\)".*/\1/')
      if [[ $UPLOAD_EXIT_CODE -ne 0 ]]; then
        if [[ -n "$STATUS" && -n "$MESSAGE" ]]; then
          echo -e "\033[1;31m[ERROR]\033[0m Status: $STATUS | Message: $MESSAGE"
        else
          echo -e "\033[1;31m[ERROR]\033[0m Upload failed after retry. Please check your credentials and configuration."
        fi
        jf config remove temp-server
        exit 1
        TASK_STATUS=$?
      else
        logInfoMessage "✅ Upload complete after retry: $ARTIFACTORY_URL/$UPLOAD_PATH"
      fi
    fi
  elif [[ -n "$STATUS" && -n "$MESSAGE" ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Status: $STATUS | Message: $MESSAGE"
    jf config remove temp-server
    exit 1
    TASK_STATUS=$?
  else
    # If no status/message found, print a generic error, but NOT the raw JSON
    echo -e "\033[1;31m[ERROR]\033[0m Upload failed. Please check your credentials and configuration."
    jf config remove temp-server
    exit 1
    TASK_STATUS=$?
  fi
fi

# logInfoMessage "✅ Upload complete: $ARTIFACTORY_URL/$UPLOAD_PATH"

# # Cleanup JFrog config
# jf config remove temp-server

TASK_STATUS=$?
saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
