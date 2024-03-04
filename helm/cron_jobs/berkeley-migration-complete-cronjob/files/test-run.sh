# Function to handle errors
error_exit() {
    echo "Error: $1" 1>&2
    exit 1
}

# Updating package lists
echo "Starting replayer cron job"
apt update || error_exit "Failed to update package lists"

# Installing libjemalloc2
echo "Installing libjemalloc2"
apt-get -y install libjemalloc2 || error_exit "Failed to install libjemalloc2"

# Installing dependencies for gsutil
echo "Installing gsutil dependencies"
apt-get -y install apt-transport-https ca-certificates gnupg curl || error_exit "Failed to install gsutil dependencies"

# Adding Google Cloud SDK repository
echo "Adding Google Cloud SDK repository"
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list || error_exit "Failed to add Google Cloud SDK repo"

# Adding Google Cloud SDK package key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - || error_exit "Failed to add Google Cloud SDK key"

# Updating package lists and installing Google Cloud CLI
apt-get update && apt-get install -y google-cloud-cli || error_exit "Failed to install Google Cloud CLI"

echo "Sleeping so you can test"
sleep 3600