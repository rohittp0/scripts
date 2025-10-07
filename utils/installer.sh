#!/bin/bash
# Install script from rohittp.com/scripts/utils/
# Usage: install.sh <script_name>

set -euo pipefail

# Configuration
BASE_URL="https://rohittp.com/scripts/utils"
INSTALL_DIR="/opt/rohittp.com/scripts"
BIN_DIR="/usr/local/bin"

# Check if script name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <script_name>"
    echo "Example: $0 osh"
    echo ""
    echo "This will download https://rohittp.com/scripts/utils/<script_name>.sh"
    echo "Install to: ${INSTALL_DIR}/<script_name>.sh"
    echo "Create symlink: ${BIN_DIR}/<script_name>"
    exit 1
fi

SCRIPT_NAME="$1"
SCRIPT_URL="${BASE_URL}/${SCRIPT_NAME}.sh"
SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}.sh"
SYMLINK_PATH="${BIN_DIR}/${SCRIPT_NAME}"

echo "Installing script: ${SCRIPT_NAME}"
echo "Source URL: ${SCRIPT_URL}"
echo "Destination: ${SCRIPT_PATH}"
echo "Symlink: ${SYMLINK_PATH}"
echo ""

# Create install directory if it doesn't exist
if [ ! -d "${INSTALL_DIR}" ]; then
    echo "Creating directory: ${INSTALL_DIR}"
    sudo mkdir -p "${INSTALL_DIR}"
fi

# Download the script (overwrite if exists)
echo "Downloading script..."
if sudo curl -fsSL "${SCRIPT_URL}" -o "${SCRIPT_PATH}"; then
    echo "✓ Successfully downloaded ${SCRIPT_NAME}.sh"
else
    echo "✗ Failed to download script from ${SCRIPT_URL}"
    echo "Please check if the script name is correct"
    exit 1
fi

# Make the script executable
sudo chmod +x "${SCRIPT_PATH}"
echo "✓ Made script executable"

# Remove existing symlink if it exists
if [ -L "${SYMLINK_PATH}" ] || [ -e "${SYMLINK_PATH}" ]; then
    echo "Removing existing symlink/file at ${SYMLINK_PATH}"
    sudo rm -f "${SYMLINK_PATH}"
fi

# Create symlink
sudo ln -s "${SCRIPT_PATH}" "${SYMLINK_PATH}"
echo "✓ Created symlink: ${SYMLINK_PATH} -> ${SCRIPT_PATH}"

# Verify installation
if command -v "${SCRIPT_NAME}" &> /dev/null; then
    echo ""
    echo "✓ Installation complete! '${SCRIPT_NAME}' is now available in your PATH"
    echo "You can run it with: ${SCRIPT_NAME}"
else
    echo ""
    echo "⚠ Installation complete but '${SCRIPT_NAME}' might not be in PATH yet"
    echo "You may need to reload your shell or add ${BIN_DIR} to your PATH"
fi
