#!/bin/bash

# Ensure a list of usernames is provided
if [ -z "$1" ]; then
    echo "Error: No usernames provided."
    echo "Usage: bash $0 username1,username2"
    exit 1
fi

TARGET_FILE="$HOME/.ssh/authorized_keys"

# Initialising: Ensure .ssh directory exists with correct secure permissions
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Ensure the authorised keys file exists so we can safely check its content later
touch "$TARGET_FILE"
chmod 600 "$TARGET_FILE"

# Split the first argument by commas into an array
IFS=',' read -r -a USERNAMES <<< "$1"

for USERNAME in "${USERNAMES[@]}"; do
    # Trim potential leading/trailing whitespaces from username
    USERNAME=$(echo "$USERNAME" | xargs)
    
    if [ -z "$USERNAME" ]; then
        continue
    fi

    echo "Fetching SSH public keys for GitHub user: ${USERNAME}..."

    # Fetch keys from GitHub API (following redirects)
    KEYS=$(curl -sSL "https://github.com/${USERNAME}.keys")

    # Check if the user exists or has any public keys
    if [ -z "$KEYS" ] || [[ "$KEYS" == *"Not Found"* ]]; then
        echo "Warning: No public keys found for user '${USERNAME}' or user does not exist. Skipping."
        continue
    fi

    # Format the header exactly as required
    HEADER="# === SSH PUB KEY FOR ${USERNAME} ==="

    # Check if this specific header already exists to avoid duplicate entries
    if grep -qF "$HEADER" "$TARGET_FILE"; then
        echo "Notice: Keys for '${USERNAME}' have already been imported previously. Skipping to prevent duplicates."
        continue
    fi

    # Append the formatted block to the authorised keys file safely
    # The awk block ensures that the keys always end with a proper newline character
    {
        echo ""
        echo "$HEADER"
        echo "$KEYS" | awk '1; END {if (NR && !/\n$/) print ""}'
    } >> "$TARGET_FILE"

    echo "Successfully appended keys for ${USERNAME}."
done

echo "SSH key import process completed."