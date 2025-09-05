#!/bin/bash

# Configure CORS for Firebase Storage
# This script applies CORS configuration to allow video playback from web browsers

echo "🔧 Configuring Firebase Storage CORS..."

# Check if gsutil is installed
if ! command -v gsutil &> /dev/null; then
    echo "❌ gsutil is not installed. Please install Google Cloud SDK first."
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get the Firebase project ID
PROJECT_ID=$(firebase use --json | jq -r '.result.project')

if [ "$PROJECT_ID" = "null" ] || [ -z "$PROJECT_ID" ]; then
    echo "❌ Could not determine Firebase project ID. Make sure you're in a Firebase project directory."
    exit 1
fi

echo "📋 Project ID: $PROJECT_ID"

# Apply CORS configuration to Firebase Storage bucket
echo "🌐 Applying CORS configuration to gs://$PROJECT_ID.appspot.com..."

gsutil cors set cors.json gs://$PROJECT_ID.appspot.com

if [ $? -eq 0 ]; then
    echo "✅ CORS configuration applied successfully!"
    echo "🎬 Video playback should now work on web browsers."
else
    echo "❌ Failed to apply CORS configuration."
    echo "Please make sure you're authenticated with Google Cloud:"
    echo "  gcloud auth login"
    echo "  gcloud config set project $PROJECT_ID"
fi

echo ""
echo "📝 To verify CORS configuration:"
echo "  gsutil cors get gs://$PROJECT_ID.appspot.com"
