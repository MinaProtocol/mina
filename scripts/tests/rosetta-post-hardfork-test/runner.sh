#!/usr/bin/env bash

# Script to generate config file from template
# Usage: ./runner.sh -n <network> -o <online_url> -f <offline_url> -k <privkey> -a <address> [-i <image>]

# Function to display help
show_help() {
    echo "🚀 Rosetta Post-Hardfork Test Runner"
    echo "═══════════════════════════════════════"
    echo "Usage: $0 -n <network> -o <online_url> -f <offline_url> -k <privkey> -a <address> [-i <image>]"
    echo ""
    echo "📋 Options:"
    echo "  -n, --network         🌐 Network name (e.g., mainnet, devnet, testnet)"
    echo "  -o, --online-url      🔗 Online URL for the network"
    echo "  -f, --offline-url     📴 Offline URL for the network"
    echo "  -k, --privkey         🔑 Hex-encoded private key for funding account (NOT base58 Mina format)"
    echo "  -a, --address         💰 Public key address in mina format"
    echo "  -i, --image           🐳 Docker image for rosetta-cli (default: docker.io/minaprotocol/rosetta-cli:mesa-hardfork-testing)"
    echo "  -h, --help            ❓ Show this help message"
    echo ""
    echo "💡 Examples:"
    echo "  $0 -n mainnet -o https://mainnet.minaprotocol.com:3085 -f https://mainnet.minaprotocol.com:3085 -k abc123def456 -a B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk"
    echo "  $0 -n testnet -o https://testnet.com:3085 -f https://testnet.com:3085 -k def789ghi012 -a B62qkXYZ... -i custom/rosetta-cli:v1.0"
}

# Initialize variables
network=""
online_url=""
offline_url=""
founder_privkey=""
recipient_publickey=""
rosetta_image="docker.io/minaprotocol/rosetta-cli:mesa-hardfork-testing"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--network)
            network="$2"
            shift 2
            ;;
        -o|--online-url)
            online_url="$2"
            shift 2
            ;;
        -f|--offline-url)
            offline_url="$2"
            shift 2
            ;;
        -k|--privkey)
            founder_privkey="$2"
            shift 2
            ;;
        -a|--address)
            recipient_publickey="$2"
            shift 2
            ;;
        -i|--image)
            rosetta_image="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done

# Apply URL fallbacks
if [ -z "$offline_url" ] && [ -n "$online_url" ]; then
    offline_url="$online_url"
    echo "ℹ️  Using online URL as offline URL: $offline_url"
elif [ -z "$online_url" ] && [ -n "$offline_url" ]; then
    online_url="$offline_url"
    echo "ℹ️  Using offline URL as online URL: $online_url"
fi

# Validate required arguments
missing_args=()
[ -z "$network" ] && missing_args+=("network (-n)")
[ -z "$online_url" ] && [ -z "$offline_url" ] && missing_args+=("at least one URL: online-url (-o) or offline-url (-f)")
[ -z "$founder_privkey" ] && missing_args+=("privkey (-k)")
[ -z "$recipient_publickey" ] && missing_args+=("address (-a)")

if [ ${#missing_args[@]} -gt 0 ]; then
    echo "❌ Error: Missing required arguments: ${missing_args[*]}"
    echo ""
    show_help
    exit 1
fi

# Check if template file exists
template_file="config_template.json"
if [ ! -f "$template_file" ]; then
    echo "❌ Error: Template file $template_file not found. Please ensure it exists in the current directory."
    exit 1
fi

echo "🔄 Initializing Rosetta test environment..."
echo "══════════════════════════════════════════════"

# Create temp directory if it doesn't exist
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Generate output filename
output_file="$temp_dir/config_${network}.json"

echo "📝 Generating configuration file for network: $network"

# Replace placeholders and create new config file using jq
jq --arg network "$network" \
   --arg online_url "$online_url" \
   --arg offline_url "$offline_url" \
   --arg privkey "$founder_privkey" \
   --arg address "$recipient_publickey" \
   '.network.network = $network |
    .online_url = $online_url |
    .construction.offline_url = $offline_url |
    .construction.prefunded_accounts[0].privkey = $privkey |
    .construction.prefunded_accounts[0].account_identifier.address = $address' \
   "$template_file" > "$output_file"

if [ $? -eq 0 ]; then
    echo "✅ Config file created successfully: $output_file"
else
    echo "❌ Error: Failed to create config file"
    exit 1
fi

# Copy and process mina.ros to temp directory if it exists
if [ -f "mina.ros" ]; then
    # Replace placeholders in mina.ros
    sed -e "s/{{network}}/{\"blockchain\": \"mina\", \"network\": \"$network\"}/g" \
        -e "s/PLACEHOLDER_PREFUNDED_ADDRESS/\"$recipient_publickey\"/g" \
        "mina.ros" > "$temp_dir/mina.ros"
    echo "📁 Processed and copied mina.ros to: $temp_dir/mina.ros"
else
    echo "⚠️  Warning: mina.ros file not found in current directory"
fi

# Run tests using the generated config file
echo ""
echo "🧪 Starting Rosetta CLI tests..."
echo "Network: 🌐 $network"
echo "Docker Image: 🐳 $rosetta_image"
echo "══════════════════════════════════════════════"

# Run spec check
echo ""
echo "🔍 STEP 1/3: Running Specification Check"
echo "════════════════════════════════════════"
echo "📋 Validating API specifications..."
docker run -v "$temp_dir":/data -i "$rosetta_image" check:spec --configuration-file /data/config_${network}.json

if [ $? -ne 0 ]; then
    echo "❌ Error: Specification check failed"
    exit 1
fi
echo "✅ Specification check completed successfully!"

# Run data check
echo ""
echo "📊 STEP 2/3: Running Data Integrity Check"
echo "═════════════════════════════════════════"
echo "⏰ Note: This might take several minutes to complete"
echo "🔄 Analyzing blockchain data integrity..."
docker run -v "$temp_dir":/data -i "$rosetta_image" check:data --configuration-file /data/config_${network}.json

if [ $? -ne 0 ]; then
    echo "❌ Error: Data integrity check failed"
    exit 1
fi
echo "✅ Data integrity check completed successfully!"

# Run construction check
echo ""
echo "🏗️  STEP 3/3: Running Construction Check"
echo "═══════════════════════════════════════"
echo "⚠️  Note: Only run this after the network has started"
echo "🔨 Testing transaction construction capabilities..."
docker run -v "$temp_dir":/data -i "$rosetta_image" check:construction --configuration-file /data/config_${network}.json

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! All tests completed successfully!"
    echo "═══════════════════════════════════════════════"
    echo "✅ Specification check: PASSED"
    echo "✅ Data integrity check: PASSED"
    echo "✅ Construction check: PASSED"
    echo ""
    echo "🚀 Your Rosetta implementation is ready for the hardfork!"
else
    echo "❌ Error: Construction check failed"
    exit 1
fi

