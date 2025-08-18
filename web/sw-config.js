// Service Worker Configuration for TALOWA Web App
// Optimized for referral system and Firebase integration

const CACHE_NAME = 'talowa-v1.0.0';
const STATIC_CACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/firebase-config.js',
  '/flutter.js',
  '/flutter_bootstrap.js',
  '/main.dart.js'
];

// Cache Firebase SDK files
const FIREBASE_CACHE_URLS = [
  'https://www.gstatic.com/firebasejs/10.12.1/firebase-app-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.1/firebase-auth-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.1/firebase-firestore-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.1/firebase-storage-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.1/firebase-messaging-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.1/firebase-remote-config-compat.js'
];

// Install event - cache static resources
self.addEventListener('install', (event) => {
  console.log('TALOWA Service Worker: Installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('TALOWA Service Worker: Caching static resources');
        return cache.addAll([...STATIC_CACHE_URLS, ...FIREBASE_CACHE_URLS]);
      })
      .then(() => {
        console.log('TALOWA Service Worker: Installation complete');
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('TALOWA Service Worker: Installation failed', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('TALOWA Service Worker: Activating...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME) {
              console.log('TALOWA Service Worker: Deleting old cache', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('TALOWA Service Worker: Activation complete');
        return self.clients.claim();
      })
  );
});

// Fetch event - serve from cache with network fallback
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // Handle referral links specially
  if (url.pathname === '/join' || url.pathname.startsWith('/join/') || url.searchParams.has('ref')) {
    console.log('TALOWA Service Worker: Handling referral link', url.href);
    
    // Always fetch referral links from network to ensure fresh content
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          // Clone the response for caching
          const responseClone = response.clone();
          
          // Cache successful responses
          if (response.status === 200) {
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(event.request, responseClone);
              });
          }
          
          return response;
        })
        .catch(() => {
          // Fallback to cached version if network fails
          return caches.match(event.request)
            .then((cachedResponse) => {
              return cachedResponse || caches.match('/index.html');
            });
        })
    );
    return;
  }
  
  // Handle API requests (Firebase, etc.)
  if (url.hostname.includes('firebase') || url.hostname.includes('googleapis')) {
    // Network first for API requests
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          // Cache successful API responses for short time
          if (response.status === 200) {
            const responseClone = response.clone();
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(event.request, responseClone);
              });
          }
          return response;
        })
        .catch(() => {
          // Fallback to cache for API requests
          return caches.match(event.request);
        })
    );
    return;
  }
  
  // Handle static resources
  if (event.request.method === 'GET') {
    event.respondWith(
      caches.match(event.request)
        .then((cachedResponse) => {
          if (cachedResponse) {
            console.log('TALOWA Service Worker: Serving from cache', event.request.url);
            return cachedResponse;
          }
          
          // Fetch from network and cache
          return fetch(event.request)
            .then((response) => {
              // Only cache successful responses
              if (response.status === 200) {
                const responseClone = response.clone();
                caches.open(CACHE_NAME)
                  .then((cache) => {
                    cache.put(event.request, responseClone);
                  });
              }
              return response;
            })
            .catch((error) => {
              console.error('TALOWA Service Worker: Fetch failed', error);
              
              // Return offline page for navigation requests
              if (event.request.mode === 'navigate') {
                return caches.match('/index.html');
              }
              
              throw error;
            });
        })
    );
  }
});

// Handle background sync for offline referral tracking
self.addEventListener('sync', (event) => {
  console.log('TALOWA Service Worker: Background sync triggered', event.tag);
  
  if (event.tag === 'referral-tracking') {
    event.waitUntil(
      // Process any pending referral tracking data
      processOfflineReferralData()
    );
  }
});

// Handle push notifications for referral system
self.addEventListener('push', (event) => {
  console.log('TALOWA Service Worker: Push notification received');
  
  if (event.data) {
    const data = event.data.json();
    
    // Handle referral-related notifications
    if (data.type === 'referral') {
      const options = {
        body: data.message || 'You have a new referral!',
        icon: '/favicon.png',
        badge: '/favicon.png',
        tag: 'referral-notification',
        data: data,
        actions: [
          {
            action: 'view',
            title: 'View Details'
          },
          {
            action: 'dismiss',
            title: 'Dismiss'
          }
        ]
      };
      
      event.waitUntil(
        self.registration.showNotification('TALOWA Referral Update', options)
      );
    }
  }
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('TALOWA Service Worker: Notification clicked', event.action);
  
  event.notification.close();
  
  if (event.action === 'view') {
    // Open the app to the relevant page
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

// Helper function to process offline referral data
async function processOfflineReferralData() {
  try {
    // This would sync any offline referral tracking data
    // when the device comes back online
    console.log('TALOWA Service Worker: Processing offline referral data');
    
    // Implementation would depend on your offline storage strategy
    // For now, just log that the sync happened
    return Promise.resolve();
  } catch (error) {
    console.error('TALOWA Service Worker: Failed to process offline data', error);
    throw error;
  }
}

// Log service worker lifecycle
console.log('TALOWA Service Worker: Script loaded');
