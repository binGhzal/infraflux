#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created common functions for all scripts
# - [ ] Add more utility functions as needed
# - [ ] Consider adding configuration file loader
# - [ ] Add logging functions that write to file

# Common functions and variables for InfraFlux deployment scripts

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Function to get the script directory
get_script_dir() {
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
}

# Function to get the project root directory  
get_project_root() {
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." &> /dev/null && pwd )"
}

# Auto-load configuration when common.sh is sourced
if [ -f "$(get_script_dir)/load-config.sh" ]; then
    source "$(get_script_dir)/load-config.sh"
    load_config >/dev/null 2>&1
fi