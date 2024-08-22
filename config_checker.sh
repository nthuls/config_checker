#!/bin/bash

# Define configuration file path and snapshot directory
user_home=$(eval echo ~$SUDO_USER)  # Get the home directory of the user who invoked sudo
config_file="$user_home/.config_file_monitor.conf"
snapshot_dir="$user_home/.config_monitor"  # Directory to store file snapshots
webhook_config_file="$user_home/.webhook_monitor.conf"  # Separate file for webhook URLs

# Check if the snapshot directory exists
if [[ ! -d "$snapshot_dir" ]]; then
    echo "Snapshot directory does not exist. Creating directory at $snapshot_dir"
    mkdir -p "$snapshot_dir"
else
    echo "Snapshot directory already exists at $snapshot_dir"
fi

# Function to get current time
current_time() {
    echo $(date '+%Y-%m-%d %H:%M:%S')
}

send_discord() {
    local file=$1
    local user=${SUDO_USER:-$(whoami)}
    local beautified_message=$2
    local current_time=$(current_time)

    # Properly escape special characters for JSON
    local escaped_message=$(echo "$beautified_message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/#/\\#/g' | awk 'ORS="\\n"' | sed 's/\\/\\\\/g')

    # Construct the JSON payload ensuring proper format
    local json_payload="{
        \"content\": \"Changes detected in $file by user $user at $current_time:\",
        \"embeds\": [{
            \"description\": \"\`\`\`diff\\n${escaped_message}\`\`\`\"
        }]
    }"

    # Output the JSON payload to the CLI for debugging
    echo "JSON payload to be sent:"
    echo "$json_payload"

    for url in "${webhook_urls[@]}"; do
        # Send the JSON payload to Discord
        curl -H "Content-Type: application/json" -d "$json_payload" $url
    done
}

# Load or ask for webhook URLs
if [[ -f "$webhook_config_file" ]]; then
    mapfile -t webhook_urls < "$webhook_config_file"
else
    echo "Enter your Discord webhook URLs, one per line. Enter a blank line when done:"
    while IFS= read -r line; do
        [[ -z $line ]] && break
        webhook_urls+=("$line")
    done
    printf "%s\n" "${webhook_urls[@]}" > "$webhook_config_file"
fi

# Function to load directories from config file or prompt user
load_or_prompt_directories() {
    if [[ "$1" == "--add-path" ]]; then
        echo "Current monitored directories:"
        cat "$config_file" | grep -v "^https://"
        echo "Enter the directories to add, separated by spaces (e.g., /etc/ssh /var/www):"
        read -a new_directories
        printf "%s\n" "${new_directories[@]}" >> "$config_file"  # Append new directories to config file
        directories=($(grep -v "^https://" "$config_file"))  # Reload directories after update, ignoring webhook URLs
    else
        if [[ -f "$config_file" ]]; then
            echo "Loading directories from config file..."
            directories=($(grep -v "^https://" "$config_file"))  # Load directories, ignoring webhook URLs
        else
            echo "Enter the directories to monitor, separated by spaces (e.g., /etc/ssh /var/www):"
            read -a directories
            printf "%s\n" "${directories[@]}" > "$config_file"  # Save directories to config file
        fi
    fi
}

# Function to sanitize file paths (replace slashes with underscores)
sanitize_path() {
    echo "$1" | sed 's|/|_|g'
}

# Function to initialize hashes and snapshots for all files in given directories
initialize_hashes() {
    if [[ -z "$(ls -A $snapshot_dir)" ]]; then
        echo "Snapshot directory is empty. Initializing hashes."
        load_or_prompt_directories
        echo "Note: Next time, use the --add-path switch to add more directories or files to monitor."

        for dir in "${directories[@]}"; do
            # Find all files in directory and subdirectories
            while IFS= read -r -d $'\0' file; do
                # Generate a sanitized file path for storage
                sanitized_file=$(sanitize_path "$file")
                snapshot_file="$snapshot_dir/$sanitized_file"

                # Store the initial content of the file
                cp "$file" "$snapshot_file"
            done < <(find "$dir" -type f -print0)
        done
    else
        echo "Snapshot directory already contains files. Monitoring existing files."
    fi
}

check_and_notify_changes() {
    local file=$1
    local user=${SUDO_USER:-$(whoami)}
    sanitized_file=$(sanitize_path "$file")
    snapshot_file="$snapshot_dir/$sanitized_file"

    # Compare current file content with the snapshot
    diff_output=$(diff "$snapshot_file" "$file")

    if [[ -z "$diff_output" ]]; then
        # No changes detected
        return
    else
        # Process each change into a structured, readable format
        beautified_message=$(echo "$diff_output" | awk '
            BEGIN {
                action = ""; changes = ""; line_info = ""; line_text = ""; first_line = 1;
            }
            /^[0-9]+[acd][0-9]+/ {
                if (!first_line) print changes "\n";  # Print previous changes before starting a new block
                first_line = 0;
                split($0, parts, /[acd]/);  # Split by action indicators
                line_info = parts[1];
                action = substr($0, length(parts[1]) + 1, 1);
                changes = "";  # Reset changes text for new block
                getline;  # Read the next line which should contain the diff
                if (action == "c") {
                    line_text = "Line " line_info " was changed from \\n";
                } else if (action == "a") {
                    line_text = "Line " parts[2] " was added: \\n";
                } else if (action == "d") {
                    line_text = "Line " line_info " was deleted: \\n";
                }
                changes = line_text;
            }
            /^</ {
                changes = changes (action == "c" ? "" : " ") substr($0, 3) "\\n";  # Append removed part
            }
            /^>/ {
                if (action == "c") {
                    changes = changes " to \\n" substr($0, 3) "\\n";  # Append changed to part
                } else {
                    changes = changes substr($0, 3) "\\n";  # Append added part
                }
            }
            END {
                if (changes != "") print changes "\n";  # Ensure last block of changes is printed
            }
        ')

        # Send the beautified message to Discord
        send_discord "$file" "$beautified_message"

        # Update the snapshot with current content
        cp "$file" "$snapshot_file"
        echo "Snapshot updated for $file"
    fi
}

# Parse command-line arguments
if [[ "$1" == "--add-path" ]]; then
    load_or_prompt_directories "--add-path"
else
    load_or_prompt_directories
fi

# Call the function to initialize snapshots if needed
initialize_hashes

# Monitoring loop
while true; do
    for dir in "${directories[@]}"; do
        # Find all files in directory and subdirectories
        while IFS= read -r -d $'\0' file; do
            if [[ -f "$file" ]]; then
                check_and_notify_changes "$file"
            fi
        done < <(find "$dir" -type f -print0)
    done
    sleep 10  # Check every 10 seconds
done
