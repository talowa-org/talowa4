#!/bin/bash

# TALOWA Production Deployment Script
# Comprehensive deployment automation for messaging system
# Usage: ./scripts/deploy_production.sh [environment] [version]

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-production}"
VERSION="${2:-$(date +%Y%m%d-%H%M%S)}"
FIREBASE_PROJECT="talowa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Error handling
handle_error() {
    log_error "Deployment failed at step: $1"
    log_error "Rolling back changes..."
    rollback_deployment
    exit 1
}

# Trap errors
trap 'handle_error "Unknown step"' ERR

# Pre-deployment checks
pre_deployment_checks() {
    log_info "Running pre-deployment checks..."
    
    # Check if required tools are installed
    command -v flutter >/dev/null 2>&1 || { log_error "Flutter is required but not installed."; exit 1; }
    command -v firebase >/dev/null 2>&1 || { log_error "Firebase CLI is required but not installed."; exit 1; }
    command -v node >/dev/null 2>&1 || { log_error "Node.js is required but not installed."; exit 1; }
    command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed."; exit 1; }
    
    # Check Firebase authentication
    if ! firebase projects:list >/dev/null 2>&1; then
        log_error "Firebase authentication required. Run 'firebase login'"
        exit 1
    fi
    
    # Check if project exists
    if ! firebase projects:list | grep -q "$FIREBASE_PROJECT"; then
        log_error "Firebase project '$FIREBASE_PROJECT' not found"
        exit 1
    fi
    
    # Check Git status
    if [[ -n $(git status --porcelain) ]]; then
        log_warning "Working directory is not clean. Uncommitted changes detected."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check if on main branch for production
    if [[ "$ENVIRONMENT" == "production" ]]; then
        current_branch=$(git branch --show-current)
        if [[ "$current_branch" != "main" ]]; then
            log_error "Production deployments must be from main branch. Current: $current_branch"
            exit 1
        fi
    fi
    
    log_success "Pre-deployment checks passed"
}

# Build Flutter application
build_flutter_app() {
    log_info "Building Flutter application for $ENVIRONMENT..."
    
    cd "$PROJECT_ROOT"
    
    # Clean previous builds
    flutter clean
    flutter pub get
    
    # Run tests before building
    log_info "Running tests..."
    flutter test --coverage || handle_error "Tests failed"
    
    # Build for web (production hosting)
    log_info "Building web application..."
    flutter build web --release --dart-define=ENVIRONMENT="$ENVIRONMENT" || handle_error "Web build failed"
    
    # Build for Android
    log_info "Building Android APK..."
    flutter build apk --release --dart-define=ENVIRONMENT="$ENVIRONMENT" || handle_error "Android build failed"
    
    # Build for iOS (if on macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "Building iOS application..."
        flutter build ios --release --dart-define=ENVIRONMENT="$ENVIRONMENT" || handle_error "iOS build failed"
    fi
    
    log_success "Flutter application built successfully"
}

# Deploy Firebase Functions
deploy_firebase_functions() {
    log_info "Deploying Firebase Functions..."
    
    cd "$PROJECT_ROOT/functions"
    
    # Install dependencies
    npm ci --production
    
    # Run function tests
    npm test || handle_error "Function tests failed"
    
    # Deploy functions
    firebase deploy --only functions --project "$FIREBASE_PROJECT" || handle_error "Functions deployment failed"
    
    log_success "Firebase Functions deployed successfully"
}

# Deploy Firestore rules and indexes
deploy_firestore_config() {
    log_info "Deploying Firestore configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Validate Firestore rules
    firebase firestore:rules:get --project "$FIREBASE_PROJECT" > /tmp/current_rules.txt
    
    # Deploy rules
    firebase deploy --only firestore:rules --project "$FIREBASE_PROJECT" || handle_error "Firestore rules deployment failed"
    
    # Deploy indexes
    firebase deploy --only firestore:indexes --project "$FIREBASE_PROJECT" || handle_error "Firestore indexes deployment failed"
    
    log_success "Firestore configuration deployed successfully"
}

# Deploy Storage rules
deploy_storage_rules() {
    log_info "Deploying Storage rules..."
    
    cd "$PROJECT_ROOT"
    
    firebase deploy --only storage --project "$FIREBASE_PROJECT" || handle_error "Storage rules deployment failed"
    
    log_success "Storage rules deployed successfully"
}

# Deploy web hosting
deploy_web_hosting() {
    log_info "Deploying web hosting..."
    
    cd "$PROJECT_ROOT"
    
    # Deploy to Firebase Hosting
    firebase deploy --only hosting --project "$FIREBASE_PROJECT" || handle_error "Web hosting deployment failed"
    
    log_success "Web hosting deployed successfully"
}

# Deploy WebSocket server
deploy_websocket_server() {
    log_info "Deploying WebSocket server..."
    
    cd "$PROJECT_ROOT/websocket-server"
    
    # Build Docker image
    docker build -t "talowa-websocket:$VERSION" . || handle_error "WebSocket server Docker build failed"
    
    # Tag for registry
    docker tag "talowa-websocket:$VERSION" "gcr.io/$FIREBASE_PROJECT/talowa-websocket:$VERSION"
    docker tag "talowa-websocket:$VERSION" "gcr.io/$FIREBASE_PROJECT/talowa-websocket:latest"
    
    # Push to Google Container Registry
    docker push "gcr.io/$FIREBASE_PROJECT/talowa-websocket:$VERSION" || handle_error "WebSocket server push failed"
    docker push "gcr.io/$FIREBASE_PROJECT/talowa-websocket:latest" || handle_error "WebSocket server latest push failed"
    
    # Deploy to Cloud Run
    gcloud run deploy talowa-websocket \
        --image "gcr.io/$FIREBASE_PROJECT/talowa-websocket:$VERSION" \
        --platform managed \
        --region us-central1 \
        --allow-unauthenticated \
        --memory 2Gi \
        --cpu 2 \
        --concurrency 1000 \
        --max-instances 100 \
        --project "$FIREBASE_PROJECT" || handle_error "WebSocket server Cloud Run deployment failed"
    
    log_success "WebSocket server deployed successfully"
}

# Deploy TURN/STUN servers
deploy_turn_servers() {
    log_info "Deploying TURN/STUN servers..."
    
    cd "$PROJECT_ROOT/turn-server"
    
    # Build Docker image
    docker build -t "talowa-turn:$VERSION" . || handle_error "TURN server Docker build failed"
    
    # Tag for registry
    docker tag "talowa-turn:$VERSION" "gcr.io/$FIREBASE_PROJECT/talowa-turn:$VERSION"
    docker tag "talowa-turn:$VERSION" "gcr.io/$FIREBASE_PROJECT/talowa-turn:latest"
    
    # Push to Google Container Registry
    docker push "gcr.io/$FIREBASE_PROJECT/talowa-turn:$VERSION" || handle_error "TURN server push failed"
    docker push "gcr.io/$FIREBASE_PROJECT/talowa-turn:latest" || handle_error "TURN server latest push failed"
    
    # Deploy to Google Kubernetes Engine
    kubectl apply -f k8s/turn-server-deployment.yaml || handle_error "TURN server Kubernetes deployment failed"
    kubectl set image deployment/talowa-turn talowa-turn="gcr.io/$FIREBASE_PROJECT/talowa-turn:$VERSION" || handle_error "TURN server image update failed"
    
    log_success "TURN/STUN servers deployed successfully"
}

# Update Remote Config
update_remote_config() {
    log_info "Updating Remote Config..."
    
    cd "$PROJECT_ROOT"
    
    # Backup current config
    firebase remoteconfig:get --project "$FIREBASE_PROJECT" > "remoteconfig/rc.backup.$(date +%Y%m%d-%H%M%S).json"
    
    # Deploy new config
    firebase remoteconfig:versions:set --template "remoteconfig/rc.template.json" --project "$FIREBASE_PROJECT" || handle_error "Remote Config deployment failed"
    
    log_success "Remote Config updated successfully"
}

# Run post-deployment tests
run_post_deployment_tests() {
    log_info "Running post-deployment tests..."
    
    cd "$PROJECT_ROOT"
    
    # Wait for services to be ready
    sleep 30
    
    # Run integration tests against production
    flutter test test/integration/production_smoke_test.dart --dart-define=ENVIRONMENT="$ENVIRONMENT" || handle_error "Post-deployment tests failed"
    
    # Run load tests (light version for production validation)
    flutter test test/performance/production_load_test.dart --dart-define=ENVIRONMENT="$ENVIRONMENT" || handle_error "Production load tests failed"
    
    # Test WebSocket connectivity
    node scripts/test_websocket_connectivity.js || handle_error "WebSocket connectivity test failed"
    
    # Test voice calling infrastructure
    node scripts/test_voice_calling.js || handle_error "Voice calling test failed"
    
    log_success "Post-deployment tests passed"
}

# Setup monitoring and alerting
setup_monitoring() {
    log_info "Setting up monitoring and alerting..."
    
    cd "$PROJECT_ROOT"
    
    # Deploy monitoring configuration
    gcloud logging sinks create talowa-errors \
        bigquery.googleapis.com/projects/"$FIREBASE_PROJECT"/datasets/logs \
        --log-filter='severity>=ERROR' \
        --project "$FIREBASE_PROJECT" 2>/dev/null || log_warning "Logging sink already exists"
    
    # Setup alerting policies
    gcloud alpha monitoring policies create --policy-from-file=monitoring/alerting-policies.yaml --project "$FIREBASE_PROJECT" || log_warning "Some alerting policies may already exist"
    
    # Deploy custom metrics
    node scripts/setup_custom_metrics.js || handle_error "Custom metrics setup failed"
    
    log_success "Monitoring and alerting configured"
}

# Create deployment backup
create_deployment_backup() {
    log_info "Creating deployment backup..."
    
    cd "$PROJECT_ROOT"
    
    # Create backup directory
    BACKUP_DIR="backups/deployment-$VERSION"
    mkdir -p "$BACKUP_DIR"
    
    # Backup Firestore rules
    firebase firestore:rules:get --project "$FIREBASE_PROJECT" > "$BACKUP_DIR/firestore.rules"
    
    # Backup Remote Config
    firebase remoteconfig:get --project "$FIREBASE_PROJECT" > "$BACKUP_DIR/remote-config.json"
    
    # Backup current deployment info
    echo "{
        \"version\": \"$VERSION\",
        \"environment\": \"$ENVIRONMENT\",
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"git_commit\": \"$(git rev-parse HEAD)\",
        \"git_branch\": \"$(git branch --show-current)\"
    }" > "$BACKUP_DIR/deployment-info.json"
    
    log_success "Deployment backup created at $BACKUP_DIR"
}

# Rollback deployment
rollback_deployment() {
    log_warning "Rolling back deployment..."
    
    # Find latest backup
    LATEST_BACKUP=$(ls -t backups/ | head -n 2 | tail -n 1)
    
    if [[ -n "$LATEST_BACKUP" ]]; then
        log_info "Rolling back to $LATEST_BACKUP"
        
        # Rollback Firestore rules
        firebase deploy --only firestore:rules --project "$FIREBASE_PROJECT" --config "backups/$LATEST_BACKUP/firestore.rules" || log_error "Firestore rules rollback failed"
        
        # Rollback Remote Config
        firebase remoteconfig:versions:set --template "backups/$LATEST_BACKUP/remote-config.json" --project "$FIREBASE_PROJECT" || log_error "Remote Config rollback failed"
        
        log_success "Rollback completed"
    else
        log_error "No backup found for rollback"
    fi
}

# Send deployment notification
send_deployment_notification() {
    log_info "Sending deployment notification..."
    
    # Send Slack notification (if webhook configured)
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚀 TALOWA $ENVIRONMENT deployment completed successfully\n• Version: $VERSION\n• Environment: $ENVIRONMENT\n• Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            "$SLACK_WEBHOOK_URL" || log_warning "Slack notification failed"
    fi
    
    # Send email notification (if configured)
    if [[ -n "${NOTIFICATION_EMAIL:-}" ]]; then
        echo "TALOWA $ENVIRONMENT deployment completed successfully
        
Version: $VERSION
Environment: $ENVIRONMENT
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Git Commit: $(git rev-parse HEAD)

Deployment included:
- Flutter web and mobile applications
- Firebase Functions
- Firestore rules and indexes
- Storage rules
- WebSocket server
- TURN/STUN servers
- Remote Config updates
- Monitoring setup

All post-deployment tests passed successfully." | mail -s "TALOWA Deployment Success - $VERSION" "$NOTIFICATION_EMAIL" || log_warning "Email notification failed"
    fi
    
    log_success "Deployment notifications sent"
}

# Main deployment function
main() {
    log_info "Starting TALOWA deployment to $ENVIRONMENT (version: $VERSION)"
    
    # Create deployment backup first
    create_deployment_backup
    
    # Run all deployment steps
    pre_deployment_checks
    build_flutter_app
    deploy_firebase_functions
    deploy_firestore_config
    deploy_storage_rules
    deploy_web_hosting
    deploy_websocket_server
    deploy_turn_servers
    update_remote_config
    setup_monitoring
    run_post_deployment_tests
    send_deployment_notification
    
    log_success "🎉 TALOWA deployment to $ENVIRONMENT completed successfully!"
    log_info "Version: $VERSION"
    log_info "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    log_info "Git Commit: $(git rev-parse HEAD)"
}

# Run main function
main "$@"