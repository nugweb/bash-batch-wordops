#!/bin/bash

# Fungsi untuk mencetak header section
print_section_header() {
    echo -e "\n=== $1 ===\n"
}

# Fungsi untuk mencetak pesan sukses
print_success() {
    echo -e "✓ $1"
}

# Fungsi untuk mencetak pesan error
print_error() {
    echo -e "✗ $1"
}

# Fungsi untuk mencetak informasi
print_info() {
    echo -e "➜ $1"
}

# Memastikan bahwa minimal dua argumen diberikan
if [ $# -lt 2 ]; then
    print_section_header "USAGE"
    echo "wo_wp_install [location] [name_new_folder] [options]"
    echo "Example: wo_wp_install /var/www/wptest.local/htdocs [nama_folder_baru] --wp --db_user=root --db_pass=password"
    exit 1
fi

# Mendapatkan argumen
LOCATION=$1
NEW_FOLDER=$2

# Mengurai opsi tambahan
DB_USER=""
DB_PASS=""
WP_INSTALL=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --wp) WP_INSTALL=true ;;
        --db_user=*) DB_USER="${1#*=}" ;;
        --db_pass=*) DB_PASS="${1#*=}" ;;
    esac
    shift
done

# Membuat path lengkap untuk folder baru
TARGET_PATH="$LOCATION/$NEW_FOLDER"

print_section_header "WORDPRESS INSTALLATION"

# Membuat folder baru di lokasi yang ditentukan
mkdir -p "$TARGET_PATH"
if [ $? -ne 0 ]; then
    print_error "Failed to create directory $TARGET_PATH"
    exit 1
fi
print_success "Directory created at $TARGET_PATH"

# Mendownload WordPress dengan indikator progress
print_info "Downloading WordPress..."
wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz --progress=bar:force 2>&1 | tail -f -n +6
if [ $? -ne 0 ]; then
    print_error "Failed to download WordPress archive"
    exit 1
fi

# Mengekstrak WordPress ke dalam folder baru
print_info "Extracting WordPress..."
tar -xf /tmp/latest.tar.gz -C "$TARGET_PATH" --strip-components=1 >/dev/null 2>&1
if [ $? -ne 0 ]; then
    print_error "Failed to extract WordPress to $TARGET_PATH"
    exit 1
fi
print_success "WordPress extracted successfully"

# Membersihkan file unduhan
rm /tmp/latest.tar.gz

# Database section
if [ "$WP_INSTALL" = true ]; then
    print_section_header "DATABASE CONFIGURATION"
    if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
        print_error "Database user or password not provided"
        print_info "Usage: --db_user=root --db_pass=password"
        exit 1
    else
        # Ambil nama root folder dan gabungkan dengan nama folder baru
        ROOT_FOLDER=$(basename $(dirname "$LOCATION"))

        # Ganti semua titik, spasi, dan karakter khusus dengan garis bawah
        DB_NAME="${ROOT_FOLDER}_${NEW_FOLDER}"
        DB_NAME=$(echo "$DB_NAME" | tr -cs '[:alnum:]_' '_')
        DB_NAME=$(echo "$DB_NAME" | sed 's/[_\ ]*$//')

        print_info "Creating MySQL database..."
        if mysql -u"$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE $DB_NAME;" 2>/dev/null; then
            print_success "Database '$DB_NAME' created successfully"
        else
            print_error "Failed to create database '$DB_NAME' (might already exist)"
        fi
    fi
fi

# WordPress Configuration using WP-CLI
print_section_header "WORDPRESS CONFIGURATION"

# Change to WordPress directory
cd "$TARGET_PATH"

# Create wp-config.php
print_info "Creating wp-config.php..."
if wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS"; then
    print_success "wp-config.php created successfully"
else
    print_error "Failed to create wp-config.php"
    exit 1
fi

# Mendapatkan nama domain dengan benar dari path
LOCATION_PATH="$LOCATION"
DOMAIN_PATH=${LOCATION_PATH%/htdocs}
DOMAIN=$(basename "$DOMAIN_PATH")

print_info "Location path: $LOCATION_PATH"
print_info "Domain path: $DOMAIN_PATH"
print_info "Domain: $DOMAIN"

# Validasi domain
if [ "$DOMAIN" = "." ] || [ -z "$DOMAIN" ] || [ "$DOMAIN" = "www" ]; then
    print_error "Could not extract domain name correctly from path"
    print_info "Path provided: $LOCATION"
    exit 1
fi

# WordPress Core Installation
print_section_header "WORDPRESS CORE INSTALLATION"

# Set URL for WordPress
WP_URL="http://$DOMAIN/$NEW_FOLDER"
WP_ADMIN_EMAIL="admin@$DOMAIN"
ADMIN_USER="useradmin"

print_info "Installing WordPress core..."
print_info "URL: $WP_URL"
print_info "Title: $NEW_FOLDER"
print_info "Admin Email: $WP_ADMIN_EMAIL"

if wp core install --url="$WP_URL" \
                  --title="$NEW_FOLDER" \
                  --admin_user="$ADMIN_USER" \
                  --admin_email="$WP_ADMIN_EMAIL" \
                  --skip-email; then
    print_success "WordPress core installed successfully"

    # Get admin password
    ADMIN_PASSWORD=$(wp user get useradmin --field=user_pass)
    print_info "Admin Username: $ADMIN_USER"
else
    print_error "Failed to install WordPress core"
    exit 1
fi


# Konfigurasi Nginx
print_section_header "NGINX CONFIGURATION"

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
print_info "Looking for Nginx configuration at: $NGINX_CONF"

# Backup dan konfigurasi Nginx
if [ -f "$NGINX_CONF" ]; then
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${NGINX_CONF}_backup_${BACKUP_DATE}"
    sudo cp "$NGINX_CONF" "$BACKUP_FILE"
    print_success "Configuration backed up to $BACKUP_FILE"

    if ! sudo grep -q "location /$NEW_FOLDER" "$NGINX_CONF"; then
        TMP_NGINX_CONF=$(mktemp)

        while IFS= read -r line; do
            if [[ $line == *"include /var/www/"* ]]; then
                cat << EOF >> "$TMP_NGINX_CONF"
    # WordPress subfolder configuration for $NEW_FOLDER
    location /$NEW_FOLDER {
        try_files \$uri \$uri/ /$NEW_FOLDER/index.php?\$args;
        index index.php index.html index.htm;

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_pass php82;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

EOF
            fi
            echo "$line" >> "$TMP_NGINX_CONF"
        done < "$NGINX_CONF"

        sudo mv "$TMP_NGINX_CONF" "$NGINX_CONF"

        print_info "Testing Nginx configuration..."
        if sudo nginx -t; then
            print_info "Reloading Nginx..."
            sudo systemctl reload nginx
            print_success "Nginx configuration updated successfully"
        else
            print_error "Nginx configuration test failed. Restoring backup..."
            sudo cp "$BACKUP_FILE" "$NGINX_CONF"
            sudo systemctl reload nginx
            print_info "Backup restored. Please check your Nginx configuration manually"
        fi
    else
        print_info "Subfolder configuration already exists in Nginx config"
    fi
else
    print_error "Nginx configuration file not found at $NGINX_CONF"
    print_info "Available configuration files:"
    sudo ls -l /etc/nginx/sites-available/
    exit 1
fi

print_section_header "INSTALLATION SUMMARY"
print_success "WordPress files installed at: $TARGET_PATH"
if [ "$MYSQL_OPTIONS" = true ]; then
    print_info "Database name: $DB_NAME"
fi
print_info "WordPress URL: $WP_URL"
print_info "Admin URL: $WP_URL/wp-admin"
print_info "Admin Username: useradmin"
