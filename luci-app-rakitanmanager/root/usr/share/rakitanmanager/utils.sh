#!/bin/bash
# Copyright 2024 RTA SERVER
# Common utility functions for RakitanManager

log_file="/var/log/rakitanmanager.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
    echo "$1"
}

# Validate IP address
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate port number
validate_port() {
    local port="$1"
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Extract host and port from host:port string
parse_host_port() {
    local host_port="$1"
    local default_port="$2"

    if [[ $host_port == *":"* ]]; then
        host=$(echo "$host_port" | cut -d: -f1)
        port=$(echo "$host_port" | cut -d: -f2)
        if ! validate_port "$port"; then
            log "Invalid port in $host_port, using default $default_port"
            port="$default_port"
        fi
    else
        host="$host_port"
        port="$default_port"
    fi

    echo "$host:$port"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts="$1"
    local command="$2"
    local attempt=1
    local delay=1

    while [ $attempt -le $max_attempts ]; do
        log "Attempt $attempt/$max_attempts: $command"
        if eval "$command"; then
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            log "Command failed, retrying in $delay seconds..."
            sleep $delay
            delay=$((delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

# Send HTTP request with timeout and retries
http_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local headers="$4"
    local max_retries=3
    local timeout=30

    local curl_cmd="curl -s --connect-timeout 10 --max-time $timeout"

    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_cmd="$curl_cmd -X POST --data '$data'"
    fi

    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd $headers"
    fi

    curl_cmd="$curl_cmd '$url'"

    local attempt=1
    while [ $attempt -le $max_retries ]; do
        log "HTTP request attempt $attempt/$max_retries: $method $url"
        local response
        response=$(eval "$curl_cmd" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$response" ]; then
            echo "$response"
            return 0
        fi

        attempt=$((attempt + 1))
        if [ $attempt -le $max_retries ]; then
            sleep 2
        fi
    done

    log "HTTP request failed after $max_retries attempts"
    return 1
}

# Get IP address from various sources
get_ip_address() {
    local interface="$1"

    # Try ubus call first (OpenWrt)
    if command_exists ubus; then
        local ip
        ip=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi

    # Try ifconfig
    if command_exists ifconfig; then
        local ip
        ip=$(ifconfig "$interface" 2>/dev/null | grep 'inet addr' | cut -d: -f2 | awk '{print $1}' | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi

    # Try ip command
    if command_exists ip; then
        local ip
        ip=$(ip addr show "$interface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi

    return 1
}

# Check if service is running
check_service() {
    local service="$1"

    if command_exists systemctl; then
        systemctl is-active --quiet "$service"
        return $?
    elif command_exists service; then
        service "$service" status >/dev/null 2>&1
        return $?
    else
        # Fallback: check process
        pgrep -f "$service" >/dev/null 2>&1
        return $?
    fi
}

# Validate configuration file
validate_config() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        log "Configuration file not found: $config_file"
        return 1
    fi

    # Basic validation - check if file is readable and not empty
    if [ ! -r "$config_file" ]; then
        log "Configuration file not readable: $config_file"
        return 1
    fi

    if [ ! -s "$config_file" ]; then
        log "Configuration file is empty: $config_file"
        return 1
    fi

    log "Configuration file validation passed: $config_file"
    return 0
}

# Clean up temporary files
cleanup_temp_files() {
    local temp_dir="${1:-/tmp}"
    local pattern="${2:-rakitanmanager_*}"

    find "$temp_dir" -name "$pattern" -type f -mtime +1 -delete 2>/dev/null || true
    log "Cleaned up temporary files matching $pattern in $temp_dir"
}

# Get system information
get_system_info() {
    echo "=== System Information ==="
    echo "Date: $(date)"
    echo "Uptime: $(uptime)"
    echo "Load Average: $(cat /proc/loadavg 2>/dev/null || echo 'N/A')"
    echo "Memory: $(free -h 2>/dev/null | grep '^Mem:' | awk '{print $3 "/" $2}' || echo 'N/A')"
    echo "Disk Usage: $(df -h / 2>/dev/null | tail -1 | awk '{print $5 " used (" $3 "/" $2 ")"}' || echo 'N/A')"
    echo "=========================="
}
