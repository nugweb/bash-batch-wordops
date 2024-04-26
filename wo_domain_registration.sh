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

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: wo_domain_registration.sh [add|delete] <domain> [ip_address]"
    exit 1
fi

# Check if the first argument is "add" or "delete"
case "$1" in
    add)
        domain=$2
        ip_address=${3:-$default_ip}
        add_to_hosts "$ip_address" "$domain"
        ;;
    delete)
        domain=$2
        delete_from_hosts "$domain"
        ;;
    *)
        echo "Invalid action. Use 'add' or 'delete'."
        exit 1
        ;;
esac

