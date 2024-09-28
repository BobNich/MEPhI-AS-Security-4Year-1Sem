#!/bin/bash

function help_message {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k, --key <API_KEY>    Use the specified Shodan API KEY"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --key YOUR_API_KEY"
}

if ! command -v shodan &> /dev/null; then
    echo "Error: Shodan CLI is not installed. Please, install it (See https://cli.shodan.io/)"
    exit 1
fi

# Argument parsing
API_KEY=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -k|--key)
            API_KEY="$2"
            shift
            ;;
        -h|--help)
            help_message
            exit 0
            ;;
        *)
            echo "Error: Invalid option: $1"
            help_message
            exit 1
            ;;
    esac
    shift
done

# Ensure API key is provided
if [[ -z "$API_KEY" ]]; then
    echo "Error: Please specify your API key using -k or --key."
    help_message
    exit 1
fi

# Initialize Shodan CLI with the API key
shodan init "$API_KEY"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to initialize Shodan CLI with the provided API key."
    exit 1
fi

# Define search query and output file
QUERY="SCADA OR PLC OR Modbus OR DNP3 OR S7"
OUTPUT_FILE="asu_tp_results.txt"

# Search for SCADA-related hosts
echo "Searching for SCADA-related hosts..."
shodan search --fields ip_str,port,org,hostnames "$QUERY" > $OUTPUT_FILE
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to execute Shodan search query."
    exit 1
fi

# Check if any hosts were found
if [[ ! -s $OUTPUT_FILE ]]; then
    echo "No hosts found matching the query."
    exit 0
fi

# Search for open ports on found hosts
echo "Checking open ports on found hosts..."
while IFS= read -r line; do
    IP=$(echo "$line" | awk '{print $1}')

    if [[ -z "$IP" ]]; then
        echo "Warning: Skipping invalid IP."
        continue
    fi

    echo "Scanning host $IP for open ports..."
    shodan host "$IP"

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to retrieve information for host $IP."
        exit 1
    fi
done < $OUTPUT_FILE

# Check for vulnerabilities on the found hosts
echo "Checking for vulnerabilities..."
while IFS= read -r line; do
    IP=$(echo "$line" | awk '{print $1}')

    if [[ -z "$IP" ]]; then
        echo "Warning: Skipping invalid IP."
        continue
    fi

    echo "Checking host $IP for known vulnerabilities..."

    # Get host data and check for vulnerabilities
    VULNS=$(shodan host "$IP" | grep "vulns")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to retrieve vulnerability information for host $IP."
        exit 1
    fi

    if [[ -n "$VULNS" ]]; then
        echo "Host $IP was compromised!"
        echo "$VULNS"
    else
        echo "Host $IP was not found in the list of compromised hosts."
    fi
done < $OUTPUT_FILE

echo "Process completed successfully."