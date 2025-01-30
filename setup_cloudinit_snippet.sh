#!/bin/bash

# Variables
SNIPPET_DIR="/var/lib/vz/snippets"
SNIPPET_NAME="proxbox-kube-ci.yml"
SCRIPT_DIR=$(pwd)
CLOUD_INIT_FILE="${SCRIPT_DIR}/terraform/cloud-init.yml"

# Enable Snippets on local storage
pvesm set local --content snippets,iso,vztmpl,backup

# Check if cloud-init.yml exists in the expected location
if [ ! -f "$CLOUD_INIT_FILE" ]; then
  echo "Error: cloud-init.yml not found in $CLOUD_INIT_FILE"
  exit 1
fi

# Ensure the snippets directory exists
if [ ! -d "$SNIPPET_DIR" ]; then
  echo "Creating snippets directory at $SNIPPET_DIR"
  mkdir -p "$SNIPPET_DIR"
else
  echo "Snippets directory already exists at $SNIPPET_DIR"
fi

# Copy the cloud-init.yml to the snippets directory with the correct name
echo "Copying cloud-init.yml to $SNIPPET_DIR as $SNIPPET_NAME"
cp "$CLOUD_INIT_FILE" "$SNIPPET_DIR/$SNIPPET_NAME"

# Confirm the file was copied successfully
if [ -f "$SNIPPET_DIR/$SNIPPET_NAME" ]; then
  echo "Snippet $SNIPPET_NAME successfully created in $SNIPPET_DIR"
else
  echo "Error: Failed to create snippet $SNIPPET_NAME in $SNIPPET_DIR"
  exit 1
fi

echo "Snippet setup complete."
