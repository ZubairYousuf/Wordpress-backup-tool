#!/bin/bash

echo "🟢 Starting WordPress Backup Script (Source Server)"

# Ask for site URL
read -p "🌐 Enter the source site URL (e.g., https://example.com): " source_url

# Strip protocol and trailing slash for filename
archive_name=$(echo "$source_url" | sed -e 's|https\?://||' -e 's|/$||')

# Extract DB credentials from wp-config.php
db_name=$(awk -F"'" '/DB_NAME/{print $4}' wp-config.php)
db_user=$(awk -F"'" '/DB_USER/{print $4}' wp-config.php)
db_password=$(awk -F"'" '/DB_PASSWORD/{print $4}' wp-config.php)
db_host_port=$(awk -F"'" '/DB_HOST/{print $4}' wp-config.php)

# Handle DB port
db_host=$(echo "$db_host_port" | cut -d: -f1)
db_port=$(echo "$db_host_port" | cut -s -d: -f2)
[ -z "$db_port" ] && db_port=3306

# Dump the database
echo "📦 Dumping database from $db_name..."
mysqldump -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_password" "$db_name" --no-tablespaces > db_backup.sql
if [ $? -ne 0 ]; then
  echo "❌ Database dump failed. Exiting."
  exit 1
fi

# Verify last 5 lines for successful dump
echo "🔍 Verifying database dump integrity..."
tail_check=$(tail -n 5 db_backup.sql | grep -Ei "INSERT INTO|-- Dump completed on|[)]\;")
if [ -z "$tail_check" ]; then
  echo "❌ Dump appears incomplete. Please re-run or verify manually."
  exit 1
fi

echo "✅ Database dumped and verified successfully."

# Script to store current working directory into a file
SOURCE_PATH=$(pwd)

# Save to a file
echo "$SOURCE_PATH" > source_path.txt
echo "✅ Source Path saved successfully."

# Compress DB
echo "🗜️ Compressing database file..."
tar -czf db_backup.tar.gz db_backup.sql && rm db_backup.sql

# Move DB tar into a temp folder to bundle it
mkdir -p .backup_meta
mv db_backup.tar.gz .backup_meta/

# Archive the full site including the DB, excluding itself and duplicate archive
echo "📁 Creating full archive: ${archive_name}.tar.gz"
tar --exclude="${archive_name}.tar.gz" --exclude="fetch-backup.sh" -czf "${archive_name}.tar.gz" . .backup_meta/

# Clean up meta folder
rm -rf .backup_meta

echo "✅ Backup process completed successfully!"
echo "📦 Final archive file created: ${archive_name}.tar.gz"
