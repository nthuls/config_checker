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
    local user=${SUDO_USER:-$(whoami)}  # Get the original user or fallback to the current user
    local beautified_message=$2
    local current_time=$(current_time)

    # Manually construct the JSON payload
    json_payload="{
        \"content\": \"Changes detected in $file by user $user at $current_time:\",
        \"embeds\": [{
            \"description\": \"\`\`\`diff\n$beautified_message\n\`\`\`\"
        }]
    }"

    # Output the JSON payload to the CLI for debugging
    echo "JSON payload to be sent:"
    echo "$json_payload"

    for url in "${webhook_urls[@]}"; do
        # Send the JSON payload to Discord
        curl -H "Content-Type: application/json" \
             -d "$json_payload" \
             $url
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

    # Echo the raw diff output for debugging
    echo "Raw diff output:"
    echo "$diff_output"

    if [[ -z "$diff_output" ]]; then
        # No changes detected
        return
    else
        # Beautify the diff output into a structured message
        beautified_message=$(echo "$diff_output" | awk '
            BEGIN {
                action = ""; line_info = ""; content = "";
            }
            /^[0-9]/ {
                if (action != "") {
                    printf "%s: %s\n", action, content;
                    content = "";
                }
                split($0, parts, /[acd]/);
                line_info = parts[1];
                if (index($0, "a") > 0) {
                    action = "Line " parts[2] " added";
                } else if (index($0, "c") > 0) {
                    action = "Line " line_info " changed to line " parts[2];
                } else if (index($0, "d") > 0) {
                    action = "Line " line_info " deleted";
                }
            }
            /^[<>]/ {
                if (content != "") content = content " ";
                content = content substr($0, 3);
            }
            END {
                if (action != "") {
                    printf "%s: %s\n", action, content;
                }
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
