#!/bin/bash

# Swish Build Script
# Usage: ./build.sh [--release] [--deploy]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Swish"
SCHEME_NAME="Swish"
BUILD_CONFIG="Debug"
DEPLOY_TO_APPLICATIONS=false
KILL_EXISTING=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_CONFIG="Release"
            shift
            ;;
        --deploy)
            DEPLOY_TO_APPLICATIONS=true
            KILL_EXISTING=true
            shift
            ;;
        --kill-only)
            KILL_EXISTING=true
            shift
            ;;
        -h|--help)
            echo "Swish Build Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --release     Build in Release configuration (default: Debug)"
            echo "  --deploy      Build and deploy to /Applications (kills existing process)"
            echo "  --kill-only   Only kill existing Swish processes"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Build Debug version"
            echo "  $0 --release          # Build Release version"
            echo "  $0 --deploy           # Build Release and deploy to Applications"
            echo "  $0 --kill-only        # Just kill existing Swish processes"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

# Function to kill existing Swish processes
kill_swish_processes() {
    print_status "Checking for existing Swish processes..."
    
    # Find and kill Swish processes
    local pids=$(pgrep -f "Swish" || true)
    
    if [ -n "$pids" ]; then
        print_warning "Found existing Swish processes: $pids"
        print_status "Terminating Swish processes..."
        pkill -f "Swish" || true
        sleep 1
        
        # Check if processes are still running
        local remaining_pids=$(pgrep -f "Swish" || true)
        if [ -n "$remaining_pids" ]; then
            print_warning "Some processes still running, force killing..."
            pkill -9 -f "Swish" || true
            sleep 1
        fi
        
        print_success "Swish processes terminated"
    else
        print_status "No existing Swish processes found"
    fi
}

# Function to build the project
build_project() {
    print_status "Building $PROJECT_NAME in $BUILD_CONFIG configuration..."
    
    # Clean build directory
    print_status "Cleaning build directory..."
    xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration "$BUILD_CONFIG" || true
    
    # Build the project
    print_status "Building project..."
    if xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration "$BUILD_CONFIG" build; then
        print_success "Build completed successfully!"
    else
        print_error "Build failed!"
        exit 1
    fi
}

# Function to deploy to Applications
deploy_to_applications() {
    print_status "Deploying to /Applications..."
    
    # Get the build product path
    local build_path=""
    if [ "$BUILD_CONFIG" = "Release" ]; then
        build_path="$(find ~/Library/Developer/Xcode/DerivedData -name 'Swish.app' -path '*/Release/*' -type d | head -1)"
    else
        build_path="$(find ~/Library/Developer/Xcode/DerivedData -name 'Swish.app' -path '*/Debug/*' -type d | head -1)"
    fi
    
    if [ -z "$build_path" ] || [ ! -d "$build_path" ]; then
        print_error "Could not find built Swish.app"
        exit 1
    fi
    
    print_status "Found build at: $build_path"
    
    # Remove existing app from Applications if it exists
    if [ -d "/Applications/$PROJECT_NAME.app" ]; then
        print_status "Removing existing app from /Applications..."
        rm -rf "/Applications/$PROJECT_NAME.app"
    fi
    
    # Copy new app to Applications
    print_status "Copying to /Applications..."
    cp -R "$build_path" "/Applications/"
    
    if [ $? -eq 0 ]; then
        print_success "Successfully deployed to /Applications"
    else
        print_error "Failed to deploy to /Applications"
        exit 1
    fi
}

# Function to launch the app
launch_app() {
    print_status "Launching Swish..."
    open "/Applications/$PROJECT_NAME.app"
    
    if [ $? -eq 0 ]; then
        print_success "Swish launched successfully!"
    else
        print_error "Failed to launch Swish"
        exit 1
    fi
}

# Main execution
main() {
    print_status "Starting Swish build process..."
    print_status "Configuration: $BUILD_CONFIG"
    print_status "Deploy to Applications: $DEPLOY_TO_APPLICATIONS"
    
    # Kill existing processes if requested
    if [ "$KILL_EXISTING" = true ]; then
        kill_swish_processes
    fi
    
    # Build the project
    build_project
    
    # Deploy if requested
    if [ "$DEPLOY_TO_APPLICATIONS" = true ]; then
        deploy_to_applications
        launch_app
    fi
    
    print_success "Build process completed!"
}

# Run main function
main "$@"
