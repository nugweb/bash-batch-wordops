#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <path_to_wordpress> [username]"
    exit 1
}

# Check for the correct number of arguments
if [ $# -lt 1 ]; then
    usage
fi

# Get the WordPress installation path
WP_PATH=$1

# Set the user to the current user if not provided
USER=${2:-$(whoami)}

# Change ownership
echo "Changing ownership to www-data:$USER for $WP_PATH/wp-config.php and $WP_PATH/htdocs"
sudo chown -R www-data:$USER "$WP_PATH/wp-config.php"
sudo chown -R www-data:$USER "$WP_PATH/htdocs"

# Change permissions for directories
echo "Changing directory permissions to 775 for $WP_PATH/htdocs"
sudo find "$WP_PATH/htdocs" -type d -exec chmod 775 {} \;

# Change permissions for files
echo "Changing file permissions to 664 for $WP_PATH/htdocs"
sudo find "$WP_PATH/htdocs" -type f -exec chmod 664 {} \;

echo "Permissions have been updated."
