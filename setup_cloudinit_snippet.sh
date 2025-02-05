#!/bin/bash

# Variables
SNIPPET_DIR="/var/lib/vz/snippets"
SNIPPET_NAME="proxbox-kube-ci.yml"
SCRIPT_DIR=$(pwd)
CLOUD_INIT_FILE="${SCRIPT_DIR}/terraform/cloud-init.yml"

# Enable Snippets on local storage
pvesm set local --content snippets,iso,vztmpl,backup

# Ensure the snippets directory exists
if [ ! -d "$SNIPPET_DIR" ]; then
  echo "Creating snippets directory at $SNIPPET_DIR"
  mkdir -p "$SNIPPET_DIR"
else
  echo "Snippets directory already exists at $SNIPPET_DIR"
fi

echo "Snippet setup complete."
