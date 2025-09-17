#!/bin/bash

PROJECT_FILE="LLMTranslator_mac.xcodeproj"
SCHEME_NAME="LLMTranslator_mac"
CONFIGURATION="Release"
SOURCE_DIR="./LLMTranslator_mac" # Directory to watch for changes

echo "Starting watch and restart script for ${SCHEME_NAME}..."

# Function to get the built application path dynamically
get_built_app_path() {
    BUILT_PRODUCTS_DIR=$(xcodebuild -project "${PROJECT_FILE}" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" -showBuildSettings | grep -E 'BUILT_PRODUCTS_DIR =' | awk '{print $3}')
    FULL_PRODUCT_NAME=$(xcodebuild -project "${PROJECT_FILE}" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" -showBuildSettings | grep -E 'FULL_PRODUCT_NAME =' | awk '{print $3}')
    echo "${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
}

BUILT_APP_PATH=$(get_built_app_path)
echo "Built application path: ${BUILT_APP_PATH}"

LAST_MD5=""

# Initial build and run
echo "Performing initial build and run..."
xcodebuild -project "${PROJECT_FILE}" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" build
if [ $? -eq 0 ]; then
    echo "Initial build successful. Launching application..."
    open "${BUILT_APP_PATH}"
else
    echo "Initial build failed. Please check for errors."
fi

while true; do
    CURRENT_MD5=$(find "${SOURCE_DIR}" -type f -print0 | sort -z | xargs -0 md5 | md5)

    if [ "${CURRENT_MD5}" != "${LAST_MD5}" ]; then
        echo "Changes detected in ${SOURCE_DIR}. Rebuilding and restarting..."

        # Kill existing app
        PID=$(pgrep "${SCHEME_NAME}")
        if [ -n "${PID}" ]; then
            echo "Killing existing process (PID: ${PID})..."
            kill "${PID}"
            sleep 1 # Give it a moment to terminate
        fi

        # Build the application
        xcodebuild -project "${PROJECT_FILE}" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" build
        if [ $? -eq 0 ]; then
            echo "Build successful. Launching application..."
            open "${BUILT_APP_PATH}"
        else
            echo "Build failed. Application not restarted."
        fi
        LAST_MD5="${CURRENT_MD5}"
    fi
    sleep 5 # Check for changes every 5 seconds
done
