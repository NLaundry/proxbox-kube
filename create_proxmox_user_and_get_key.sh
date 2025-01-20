#!/bin/bash

# Colors for status updates
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Function to print status messages
function print_status() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

function print_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root."
    exit 1
fi

# Inputs: root password, username, new user password, tokenid
root_password="${1}"
username="${2}"
new_password="${3}"
tokenid="${4}"

# Prompt for root password if not provided
if [[ -z "$root_password" ]]; then
    read -s -p "Enter the root password for confirmation: " root_password
    echo
fi

# Prompt for username if not provided
if [[ -z "$username" ]]; then
    read -p "Enter the username for the new user: " username
fi

# Prompt for new user password if not provided
if [[ -z "$new_password" ]]; then
    read -s -p "Enter the password for the new user: " new_password
    echo
fi

# Prompt for token ID if not provided
if [[ -z "$tokenid" ]]; then
    read -p "Enter the token ID for the new user: " tokenid
fi

realm="pve"

print_status "Creating user: ${username}@${realm}..."
if pveum user add "${username}@${realm}"; then
    print_status "User ${username}@${realm} created successfully."
else
    print_error "Failed to create user ${username}@${realm}. Exiting."
    exit 1
fi

print_status "Setting password for ${username}@${realm}..."
if pveum passwd "${username}@${realm}" --password "${new_password}" --confirmation-password "${root_password}"; then
    print_status "Password set successfully."
else
    print_error "Failed to set password. Exiting."
    exit 1
fi

print_status "Assigning Administrator role to ${username}@${realm}..."
if pveum aclmod / -user "${username}@${realm}" -role Administrator; then
    print_status "Role assigned successfully."
else
    print_error "Failed to assign role. Exiting."
    exit 1
fi

print_status "Generating API token for ${username}@${realm} with ID ${tokenid}..."
token_output=$(pveum user token add "${username}@${realm}" "${tokenid}" --noheader=1 --noborder=1 2>&1)
if [[ $? -eq 0 ]]; then
    print_status "API token created successfully."
else
    print_error "Failed to create API token: $token_output"
    exit 1
fi

# Extract TokenID and Secret from the output
token_id=$(echo "$token_output" | awk '/full-tokenid/ {print $2}')
secret=$(echo "$token_output" | awk '/value/ {print $2}')

if [[ -z "$token_id" || -z "$secret" ]]; then
    print_error "Failed to extract the API token ID or secret. Exiting."
    exit 1
fi

# Save to file
output_file="token_data.txt"
echo -e "TokenID: ${token_id}\nSecret: ${secret}" > "$output_file"

print_status "API token saved to ${output_file}."

# Final message
echo -e "${GREEN}All steps completed successfully!${RESET}"

