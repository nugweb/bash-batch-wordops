#!/bin/bash

# Set the default IP address
default_ip="127.0.1.1"
hosts_file="/etc/hosts"

# Function to add an entry to /etc/hosts
add_to_hosts() {
    local ip=$1
    local domain=$2

    # Check if the domain already exists in /etc/hosts
    if grep -q "$domain" "$hosts_file"; then
        echo "The domain $domain already exists in $hosts_file."
    else
        # Append the domain to /etc/hosts
        echo "$ip $domain" | sudo tee -a "$hosts_file"
        echo "Added $domain with IP $ip to $hosts_file."
    fi
}

# Function to delete an entry from /etc/hosts
delete_from_hosts() {
    local domain=$1

    # Check if the domain exists in /etc/hosts
    if grep -q "$domain" "$hosts_file"; then
        # Use sudo and sed to remove the line containing the domain
        sudo sed -i "/$domain/d" "$hosts_file"
        echo "Deleted $domain from $hosts_file."
    else
        echo "The domain $domain does not exist in $hosts_file."
    fi
}

# Function to view the registered domains in /etc/hosts
view_hosts() {
    echo "Registered domains in $hosts_file:"
    # Print the lines that contain domain registrations
    grep -vE '^#|^$' "$hosts_file"
}

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: wo_domain_registration.sh [add|delete|view] <domain> [ip_address]"
    exit 1
fi

# Check the action
case "$1" in
    add)
        if [ -z "$2" ]; then
            echo "Please provide a domain to add."
            exit 1
        fi
        domain=$2
        ip_address=${3:-$default_ip}
        add_to_hosts "$ip_address" "$domain"
        ;;
    delete)
        if [ -z "$2" ]; then
            echo "Please provide a domain to delete."
            exit 1
        fi
        domain=$2
        delete_from_hosts "$domain"
        ;;
    view)
        view_hosts
        ;;
    *)
        echo "Invalid action. Use 'add', 'delete', or 'view'."
        exit 1
        ;;
esac
