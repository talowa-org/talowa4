@echo off
echo Setting up CORS for Firebase Storage...
echo.

echo Step 1: Creating CORS configuration file...
echo [
echo   {
echo     "origin": ["https://talowa.web.app", "https://talowa.firebaseapp.com", "http://localhost:*"],
echo     "method": ["GET", "HEAD", "PUT", "POST", "DELETE", "OPTIONS"],
echo     "responseHeader": ["Content-Type", "Access-Control-Allow-Origin", "Access-Control-Allow-Methods", "Access-Control-Allow-Headers"],
echo     "maxAgeSeconds": 3600
echo   }
echo ] > cors.json

echo.
echo Step 2: CORS configuration file created as 'cors.json'
echo.
echo Step 3: To apply CORS configuration, run:
echo gsutil cors set cors.json gs://talowa.firebasestorage.app
echo.
echo Note: You need Google Cloud SDK installed for this to work.
echo.
echo Alternative: Copy the cors.json content and paste it in Google Cloud Console
echo under Storage ^> Bucket Configuration ^> CORS
echo.
pause
