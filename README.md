# File Monitoring and Discord Notification Script

This guide will walk you through configuring a file monitoring script that detects changes in specified directories and files and sends notifications to a Discord channel via a webhook. The script can be tailored to meet various needs, whether for monitoring configuration files or any other files of interest.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Script Overview](#script-overview)
3. [Setting Up the Script](#setting-up-the-script)
   - [Step 1: Download and Place the Script](#step-1-download-and-place-the-script)
   - [Step 2: Configure Webhook URLs](#step-2-configure-webhook-urls)
   - [Step 3: Configure Directories to Monitor](#step-3-configure-directories-to-monitor)
4. [Running the Script](#running-the-script)
5. [Customizing the Script](#customizing-the-script)
   - [Adding/Removing Directories](#addingremoving-directories)
   - [Adjusting Monitoring Frequency](#adjusting-monitoring-frequency)
   - [Customizing the Notification Message](#customizing-the-notification-message)
6. [Testing and Performance](#testing-and-performance)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

- **Bash**: The script is written in Bash, so you need a Unix-like operating system (Linux, macOS, or WSL on Windows).
- **curl**: Ensure `curl` is installed for sending HTTP requests to Discord.
- **Discord Webhook**: A Discord server with a webhook URL to receive notifications.

## Script Overview

This script monitors specified directories for any changes in the files. When a change is detected, the script:
- Compares the current file content with a saved snapshot.
- Generates a diff output in a readable format.
- Sends a notification to a Discord channel with the details of the change.

## Setting Up the Script

### Step 1: Download and Place the Script

1. Clone or download the script from the repository.
2. Place the script in a directory where it has read/write access to the files it will monitor.

### Step 2: Configure Webhook URLs

1. When you first run the script, it will prompt you to enter one or more Discord webhook URLs.
2. These URLs will be stored in a configuration file located at `~/.webhook_monitor.conf` for future use.

If you need to change the webhook URLs later, simply delete or edit the `~/.webhook_monitor.conf` file, and the script will prompt you to re-enter the URLs the next time it runs.

### Step 3: Configure Directories to Monitor

1. The script will also prompt you to enter the directories you wish to monitor. These will be saved in `~/.config_file_monitor.conf`.
2. You can specify multiple directories or files, separated by spaces.

**Example:**
```sh
/etc/nginx /var/www/html /etc/hosts
```

To add more directories later, you can run the script with the `--add-path` switch:
```bash
./monitor_script.sh --add-path
```

## Running the Script

Simply execute the script using:
```bash
./monitor_script.sh
```

The script will begin monitoring the specified directories and files. It will check for changes every 10 seconds by default.

## Customizing the Script

### Adding/Removing Directories

To add new directories or files to the monitoring list:
1. Run the script with the `--add-path` switch.
2. Enter the directories or files you want to monitor.

To remove a directory or file, edit the `~/.config_file_monitor.conf` file manually and remove the line corresponding to the directory or file you wish to stop monitoring.

### Adjusting Monitoring Frequency

By default, the script checks for changes every 10 seconds. To adjust this frequency:
1. Open the script in a text editor.
2. Find the line:
   ```bash
   sleep 10  # Check every 10 seconds
   ```
3. Change `10` to your desired number of seconds.

### Customizing the Notification Message

If you want to modify the format of the notification message sent to Discord:
1. Edit the `send_discord` function in the script.
2. Modify the `escaped_message` variable to change how the message is formatted.

You can adjust the diff formatting or even add additional information like timestamps, usernames, or file paths.

## Testing and Performance

To test how the script performs under load or in a production environment, you can:
1. Increase the number of files being monitored.
2. Simulate frequent file changes.
3. Measure the script's performance using tools like `time`, `top`, or `htop`.

For a detailed guide on performance testing, see the section on [Testing the Performance](#testing-the-performance) in the documentation.

## Troubleshooting

### Common Issues

- **Permission Errors**: Ensure the script has sufficient permissions to read and write to the monitored directories.
- **No Notifications**: Check that your webhook URL is correct and the script can reach Discord's servers. Verify internet connectivity.
- **High CPU Usage**: If monitoring a large number of files or directories, consider reducing the frequency of checks or optimizing the script.

For any other issues or customization requests, feel free to consult the community or the script's documentation.
