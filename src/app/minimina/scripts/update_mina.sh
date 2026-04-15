#!/bin/bash
# This script is used to update the mina daemon and archive node version in the project.
# Usage: 
#  1. Update the variables below to the desired versions
#  2. ./scripts/update_mina.sh

daemon_old="gcr.io/o1labs-192920/mina-daemon:2.0.0rampup7-4a0fff9-bullseye-berkeley"
daemon_new="gcr.io/o1labs-192920/mina-daemon:2.0.0berkeley-rc1-1551e2f-bullseye-berkeley"

archive_old="gcr.io/o1labs-192920/mina-archive:2.0.0rampup7-4a0fff9-bullseye"
archive_new="gcr.io/o1labs-192920/mina-archive:2.0.0berkeley-rc1-1551e2f-bullseye"

commit_old="4a0fff9"
commit_new="1551e2f"

escape_slashes() {
    echo "$1" | sed 's_/_\\/_g'
}

daemon_old_escaped=$(escape_slashes "$daemon_old")
daemon_new_escaped=$(escape_slashes "$daemon_new")
archive_old_escaped=$(escape_slashes "$archive_old")
archive_new_escaped=$(escape_slashes "$archive_new")

# Function to generate the sed command
generate_sed_command() {
    echo "sed -i 's|$1|$2|g;s|$3|$4|g;s|$5|$6|g' \$1"
}

# Generate the sed command
sed_command=$(generate_sed_command "$daemon_old_escaped" "$daemon_new_escaped" "$archive_old_escaped" "$archive_new_escaped" "$commit_old" "$commit_new")

# Apply replacements in files under 'src' and 'tests' directories
find "./src" -type f -exec bash -c "$sed_command" bash {} \;
find "./tests" -type f -exec bash -c "$sed_command" bash {} \;
