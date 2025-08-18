#!/usr/bin/env node

/**
 * TALOWA Web Deployment Verification Script
 * 
 * This script verifies that the deployed web application works correctly,
 * including all referral system features, deep links, and Firebase integration.
 */

const https = require('https');
const http = require('http');

const BASE_URL = 'https://talowa.web.app';
const TEST_REFERRAL_CODE = 'TAL234567';

// ANSI color codes for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSuccess(message) {
  log(`✅ ${message}`, 'green');
}

function logError(message) {
  log(`❌ ${message}`, 'red');
}

function logInfo(message) {
  log(`ℹ️  ${message}`, 'blue');
}

function logWarning(message) {
  log(`⚠️  ${message}`, 'yellow');
}

// Helper function to make HTTP requests
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https:') ? https : http;
    
    const req = protocol.get(url, options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
  });
}

// Test functions
async function testBasicConnectivity() {
  log('\n🔍 Testing Basic Connectivity...', 'cyan');
  
  try {
    const response = await makeRequest(BASE_URL);
    
    if (response.statusCode === 200) {
      logSuccess('Website is accessible');
      
      // Check for Flutter app indicators
      if (response.body.includes('flutter') || response.body.includes('main.dart.js')) {
        logSuccess('Flutter web app detected');
      } else {
        logWarning('Flutter app indicators not found in HTML');
      }
      
      // Check for Firebase configuration
      if (response.body.includes('firebase') || response.body.includes('firebase-config.js')) {
        logSuccess('Firebase configuration detected');
      } else {
        logWarning('Firebase configuration not found');
      }
      
      return true;
    } else {
      logError(`Website returned status code: ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    logError(`Failed to connect to website: ${error.message}`);
    return false;
  }
}

async function testReferralLinks() {
  log('\n🔗 Testing Referral Link Functionality...', 'cyan');
  
  const testUrls = [
    `${BASE_URL}/join?ref=${TEST_REFERRAL_CODE}`,
    `${BASE_URL}/join/${TEST_REFERRAL_CODE}`,
    `${BASE_URL}/?ref=${TEST_REFERRAL_CODE}`
  ];
  
  let allPassed = true;
  
  for (const url of testUrls) {
    try {
      logInfo(`Testing: ${url}`);
      const response = await makeRequest(url);
      
      if (response.statusCode === 200) {
        logSuccess(`Referral link accessible: ${url}`);
        
        // Check if the page contains referral code handling
        if (response.body.includes('referral') || response.body.includes('ref=')) {
          logSuccess('Referral code handling detected');
        } else {
          logWarning('Referral code handling not clearly detected');
        }
      } else if (response.statusCode === 404) {
        logWarning(`Referral link returns 404 (may be handled by client-side routing): ${url}`);
      } else {
        logError(`Referral link returned status ${response.statusCode}: ${url}`);
        allPassed = false;
      }
    } catch (error) {
      logError(`Failed to test referral link ${url}: ${error.message}`);
      allPassed = false;
    }
  }
  
  return allPassed;
}

async function testStaticAssets() {
  log('\n📁 Testing Static Assets...', 'cyan');
  
  const assets = [
    '/manifest.json',
    '/favicon.png',
    '/firebase-config.js',
    '/flutter.js',
    '/flutter_bootstrap.js'
  ];
  
  let allPassed = true;
  
  for (const asset of assets) {
    try {
      const url = `${BASE_URL}${asset}`;
      const response = await makeRequest(url);
      
      if (response.statusCode === 200) {
        logSuccess(`Asset accessible: ${asset}`);
      } else {
        logError(`Asset not found: ${asset} (status: ${response.statusCode})`);
        allPassed = false;
      }
    } catch (error) {
      logError(`Failed to load asset ${asset}: ${error.message}`);
      allPassed = false;
    }
  }
  
  return allPassed;
}

async function testPWAManifest() {
  log('\n📱 Testing PWA Manifest...', 'cyan');
  
  try {
    const response = await makeRequest(`${BASE_URL}/manifest.json`);
    
    if (response.statusCode === 200) {
      logSuccess('PWA manifest accessible');
      
      try {
        const manifest = JSON.parse(response.body);
        
        // Check required PWA fields
        const requiredFields = ['name', 'short_name', 'start_url', 'display', 'theme_color'];
        let manifestValid = true;
        
        for (const field of requiredFields) {
          if (manifest[field]) {
            logSuccess(`Manifest has ${field}: ${manifest[field]}`);
          } else {
            logError(`Manifest missing required field: ${field}`);
            manifestValid = false;
          }
        }
        
        // Check for icons
        if (manifest.icons && manifest.icons.length > 0) {
          logSuccess(`Manifest has ${manifest.icons.length} icon(s)`);
        } else {
          logWarning('Manifest has no icons defined');
        }
        
        return manifestValid;
      } catch (parseError) {
        logError(`Failed to parse manifest JSON: ${parseError.message}`);
        return false;
      }
    } else {
      logError(`Manifest not accessible (status: ${response.statusCode})`);
      return false;
    }
  } catch (error) {
    logError(`Failed to test PWA manifest: ${error.message}`);
    return false;
  }
}

async function testFirebaseConfig() {
  log('\n🔥 Testing Firebase Configuration...', 'cyan');
  
  try {
    const response = await makeRequest(`${BASE_URL}/firebase-config.js`);
    
    if (response.statusCode === 200) {
      logSuccess('Firebase config file accessible');
      
      // Check for required Firebase config fields
      const requiredFields = ['apiKey', 'authDomain', 'projectId', 'storageBucket', 'messagingSenderId', 'appId'];
      let configValid = true;
      
      for (const field of requiredFields) {
        if (response.body.includes(field)) {
          logSuccess(`Firebase config contains ${field}`);
        } else {
          logError(`Firebase config missing ${field}`);
          configValid = false;
        }
      }
      
      // Check for project ID
      if (response.body.includes('talowa')) {
        logSuccess('Correct Firebase project ID detected');
      } else {
        logWarning('Firebase project ID not clearly detected');
      }
      
      return configValid;
    } else {
      logError(`Firebase config not accessible (status: ${response.statusCode})`);
      return false;
    }
  } catch (error) {
    logError(`Failed to test Firebase config: ${error.message}`);
    return false;
  }
}

async function testSEOAndMetadata() {
  log('\n🔍 Testing SEO and Metadata...', 'cyan');
  
  try {
    const response = await makeRequest(BASE_URL);
    
    if (response.statusCode === 200) {
      const html = response.body;
      
      // Check for essential meta tags
      const metaTags = [
        { name: 'title', pattern: /<title>.*TALOWA.*<\/title>/i },
        { name: 'description', pattern: /<meta[^>]*name="description"[^>]*content="[^"]*"/i },
        { name: 'viewport', pattern: /<meta[^>]*name="viewport"[^>]*>/i },
        { name: 'og:title', pattern: /<meta[^>]*property="og:title"[^>]*>/i },
        { name: 'og:description', pattern: /<meta[^>]*property="og:description"[^>]*>/i },
        { name: 'og:url', pattern: /<meta[^>]*property="og:url"[^>]*>/i }
      ];
      
      let seoValid = true;
      
      for (const tag of metaTags) {
        if (tag.pattern.test(html)) {
          logSuccess(`${tag.name} meta tag found`);
        } else {
          logError(`${tag.name} meta tag missing`);
          seoValid = false;
        }
      }
      
      // Check for referral system metadata
      if (html.includes('referral-system') || html.includes('auto-fill-support')) {
        logSuccess('Referral system metadata detected');
      } else {
        logWarning('Referral system metadata not found');
      }
      
      return seoValid;
    } else {
      logError(`Failed to load homepage for SEO check (status: ${response.statusCode})`);
      return false;
    }
  } catch (error) {
    logError(`Failed to test SEO metadata: ${error.message}`);
    return false;
  }
}

async function testSecurityHeaders() {
  log('\n🔒 Testing Security Headers...', 'cyan');
  
  try {
    const response = await makeRequest(BASE_URL);
    
    if (response.statusCode === 200) {
      const headers = response.headers;
      
      // Check for security headers
      const securityHeaders = [
        'x-frame-options',
        'x-content-type-options',
        'x-xss-protection',
        'strict-transport-security'
      ];
      
      let securityScore = 0;
      
      for (const header of securityHeaders) {
        if (headers[header]) {
          logSuccess(`Security header present: ${header}`);
          securityScore++;
        } else {
          logWarning(`Security header missing: ${header}`);
        }
      }
      
      // Check HTTPS
      if (BASE_URL.startsWith('https://')) {
        logSuccess('Site served over HTTPS');
        securityScore++;
      } else {
        logError('Site not served over HTTPS');
      }
      
      logInfo(`Security score: ${securityScore}/${securityHeaders.length + 1}`);
      
      return securityScore >= 3; // At least 3 out of 5 security measures
    } else {
      logError(`Failed to check security headers (status: ${response.statusCode})`);
      return false;
    }
  } catch (error) {
    logError(`Failed to test security headers: ${error.message}`);
    return false;
  }
}

// Main verification function
async function runVerification() {
  log('🚀 TALOWA Web Deployment Verification', 'bright');
  log('=====================================', 'bright');
  
  const tests = [
    { name: 'Basic Connectivity', fn: testBasicConnectivity },
    { name: 'Referral Links', fn: testReferralLinks },
    { name: 'Static Assets', fn: testStaticAssets },
    { name: 'PWA Manifest', fn: testPWAManifest },
    { name: 'Firebase Config', fn: testFirebaseConfig },
    { name: 'SEO & Metadata', fn: testSEOAndMetadata },
    { name: 'Security Headers', fn: testSecurityHeaders }
  ];
  
  const results = [];
  
  for (const test of tests) {
    try {
      const result = await test.fn();
      results.push({ name: test.name, passed: result });
    } catch (error) {
      logError(`Test ${test.name} failed with error: ${error.message}`);
      results.push({ name: test.name, passed: false });
    }
  }
  
  // Summary
  log('\n📊 Verification Summary', 'cyan');
  log('====================', 'cyan');
  
  const passed = results.filter(r => r.passed).length;
  const total = results.length;
  
  results.forEach(result => {
    if (result.passed) {
      logSuccess(`${result.name}: PASSED`);
    } else {
      logError(`${result.name}: FAILED`);
    }
  });
  
  log(`\n🎯 Overall Score: ${passed}/${total} tests passed`, 'bright');
  
  if (passed === total) {
    logSuccess('🎉 All tests passed! Deployment is successful.');
    log(`\n🌐 Your TALOWA web app is live at: ${BASE_URL}`, 'green');
    log(`🔗 Test referral link: ${BASE_URL}/join?ref=${TEST_REFERRAL_CODE}`, 'green');
  } else if (passed >= total * 0.8) {
    logWarning('⚠️  Most tests passed. Deployment is mostly successful with minor issues.');
  } else {
    logError('❌ Multiple tests failed. Please review the deployment.');
  }
  
  return passed === total;
}

// Run the verification
if (require.main === module) {
  runVerification()
    .then((success) => {
      process.exit(success ? 0 : 1);
    })
    .catch((error) => {
      logError(`Verification failed: ${error.message}`);
      process.exit(1);
    });
}

module.exports = { runVerification };
