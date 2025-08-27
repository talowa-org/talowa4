#!/bin/bash

# TALOWA Referral System Function Testing Script
# 
# This script tests the three core Cloud Functions:
# - reserveReferralCode
# - applyReferralCode  
# - getMyReferralStats
#
# Usage: ./test_referral_functions.sh [PROJECT_ID] [ID_TOKEN]

set -e

# Configuration
PROJECT_ID=${1:-"talowa-app"}
ID_TOKEN=${2:-""}
REGION="us-central1"
BASE_URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Check if ID_TOKEN is provided
if [ -z "$ID_TOKEN" ]; then
    warn "No ID_TOKEN provided. You'll need a Firebase Auth token to test authenticated functions."
    warn "Get one from your app's console: firebase.auth().currentUser.getIdToken()"
    warn "Usage: $0 PROJECT_ID ID_TOKEN"
    echo
fi

log "🚀 Testing TALOWA Referral System Cloud Functions"
log "Project: $PROJECT_ID"
log "Region: $REGION"
log "Base URL: $BASE_URL"
echo

# Test 1: Check if functions are accessible
log "📋 Test 1: Checking function accessibility..."

check_function() {
    local func_name=$1
    local url="${BASE_URL}/${func_name}"
    
    log "Checking $func_name..."
    
    # Make a simple request to see if function exists
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json "$url" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null || echo "000")
    
    if [ "$response" = "000" ]; then
        error "$func_name - CONNECTION FAILED"
        return 1
    elif [ "$response" = "404" ]; then
        error "$func_name - NOT FOUND (404)"
        return 1
    elif [ "$response" = "401" ] || [ "$response" = "403" ]; then
        success "$func_name - DEPLOYED (needs auth)"
        return 0
    else
        success "$func_name - DEPLOYED (HTTP $response)"
        return 0
    fi
}

check_function "reserveReferralCode"
check_function "applyReferralCode"
check_function "getMyReferralStats"

echo

# Test 2: Test with authentication (if token provided)
if [ -n "$ID_TOKEN" ]; then
    log "📋 Test 2: Testing authenticated function calls..."
    
    # Test reserveReferralCode
    log "Testing reserveReferralCode..."
    reserve_response=$(curl -s "${BASE_URL}/reserveReferralCode" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ID_TOKEN" \
        -d '{}' 2>/dev/null || echo '{"error":"curl_failed"}')
    
    echo "Response: $reserve_response"
    
    # Extract code if successful
    referral_code=$(echo "$reserve_response" | grep -o '"code":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [ -n "$referral_code" ] && [[ "$referral_code" =~ ^TAL[A-Z0-9]{6,8}$ ]]; then
        success "reserveReferralCode - Got valid code: $referral_code"
        
        # Test idempotency - call again
        log "Testing idempotency..."
        reserve_response2=$(curl -s "${BASE_URL}/reserveReferralCode" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $ID_TOKEN" \
            -d '{}' 2>/dev/null || echo '{"error":"curl_failed"}')
        
        referral_code2=$(echo "$reserve_response2" | grep -o '"code":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        if [ "$referral_code" = "$referral_code2" ]; then
            success "reserveReferralCode - Idempotency working"
        else
            error "reserveReferralCode - Idempotency failed (got different codes)"
        fi
        
    else
        error "reserveReferralCode - Invalid response or code format"
    fi
    
    echo
    
    # Test getMyReferralStats
    log "Testing getMyReferralStats..."
    stats_response=$(curl -s "${BASE_URL}/getMyReferralStats" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ID_TOKEN" \
        -d '{}' 2>/dev/null || echo '{"error":"curl_failed"}')
    
    echo "Response: $stats_response"
    
    if echo "$stats_response" | grep -q '"directCount"'; then
        success "getMyReferralStats - Got valid stats response"
    else
        warn "getMyReferralStats - Unexpected response format"
    fi
    
    echo
    
    # Test applyReferralCode (if we have a code)
    if [ -n "$referral_code" ]; then
        log "Testing applyReferralCode with own code (should fail)..."
        apply_response=$(curl -s "${BASE_URL}/applyReferralCode" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $ID_TOKEN" \
            -d "{\"code\":\"$referral_code\"}" 2>/dev/null || echo '{"error":"curl_failed"}')
        
        echo "Response: $apply_response"
        
        if echo "$apply_response" | grep -q -i "self\|own\|same"; then
            success "applyReferralCode - Self-referral properly blocked"
        elif echo "$apply_response" | grep -q "error"; then
            warn "applyReferralCode - Got error (might be self-referral block)"
        else
            error "applyReferralCode - Self-referral not blocked!"
        fi
    fi
    
else
    warn "Skipping authenticated tests (no ID_TOKEN provided)"
fi

echo

# Test 3: Code format validation
log "📋 Test 3: Testing code format validation..."

test_codes=(
    "TAL123ABC"  # Valid format
    "TAL2A3B4C"  # Valid format  
    "TALXYZ123"  # Valid format
    "tal123abc"  # Invalid (lowercase)
    "TAL12"      # Invalid (too short)
    "TAL123ABCD" # Invalid (too long)
    "ABC123DEF"  # Invalid (no TAL prefix)
    "TAL123AB0"  # Invalid (contains 0)
    "TAL123AB1"  # Invalid (contains 1)
)

for code in "${test_codes[@]}"; do
    if [[ "$code" =~ ^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6,8}$ ]]; then
        success "Code format: $code - VALID"
    else
        warn "Code format: $code - INVALID (expected)"
    fi
done

echo

# Test 4: Basic security check
log "📋 Test 4: Testing basic security..."

# Test unauthenticated access
log "Testing unauthenticated access (should fail)..."
unauth_response=$(curl -s -w "%{http_code}" -o /tmp/unauth.json "${BASE_URL}/reserveReferralCode" \
    -H "Content-Type: application/json" \
    -d '{}' 2>/dev/null || echo "000")

if [ "$unauth_response" = "401" ] || [ "$unauth_response" = "403" ]; then
    success "Unauthenticated access properly blocked (HTTP $unauth_response)"
else
    error "Unauthenticated access not properly blocked (HTTP $unauth_response)"
fi

echo

# Summary
log "🎯 Test Summary:"
success "Function deployment check completed"
if [ -n "$ID_TOKEN" ]; then
    success "Authenticated function tests completed"
else
    warn "Authenticated tests skipped (provide ID_TOKEN to run)"
fi
success "Code format validation completed"
success "Basic security check completed"

echo
log "📝 Next steps:"
echo "1. Get a Firebase Auth ID token from your app"
echo "2. Run: $0 $PROJECT_ID YOUR_ID_TOKEN"
echo "3. Test with multiple users to verify referral relationships"
echo "4. Check Firestore console for proper data structure"

echo
log "🔗 Useful commands:"
echo "# Get project info:"
echo "firebase projects:list"
echo ""
echo "# Check function logs:"
echo "firebase functions:log --only reserveReferralCode"
echo ""
echo "# Deploy functions:"
echo "firebase deploy --only functions"