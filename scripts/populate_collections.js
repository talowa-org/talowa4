// Script to populate missing Firestore collections
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('../firebase-service-account.json'); // You'll need to add this
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'talowa'
});

const db = admin.firestore();

async function populateDailyMotivation() {
  console.log('Populating daily motivation collection...');
  
  const motivationData = {
    messages: [
      "आज एक नया दिन है। अपनी भूमि के लिए लड़ते रहें। (Today is a new day. Keep fighting for your land.)",
      "एकजुट होकर हम अपने अधिकारों को पा सकते हैं। (United we can achieve our rights.)",
      "हर छोटा कदम बड़े बदलाव की शुरुआत है। (Every small step is the beginning of big change.)",
      "आपकी आवाज़ मायने रखती है। बोलते रहें। (Your voice matters. Keep speaking up.)",
      "न्याय की लड़ाई में हम साथ हैं। (We are together in the fight for justice.)",
      "भूमि हमारा अधिकार है, हम इसे पाकर रहेंगे। (Land is our right, we will get it.)",
      "संगठन में शक्ति है। एक साथ चलें। (There is strength in organization. Let's move together.)",
      "हमारे बच्चों के लिए एक बेहतर कल बनाएं। (Create a better tomorrow for our children.)",
      "कानूनी लड़ाई में धैर्य और दृढ़ता जरूरी है। (Patience and persistence are necessary in legal battles.)",
      "आपका संघर्ष व्यर्थ नहीं है। जारी रखें। (Your struggle is not in vain. Continue.)"
    ],
    success_stories: [
      {
        title: "करीमनगर में 500 एकड़ भूमि वापसी",
        description: "सामूहिक प्रयास से किसानों को अपनी भूमि वापस मिली।",
        location: "करीमनगर, तेलंगाना",
        date: "2024-01-15"
      },
      {
        title: "वारंगल में पट्टा वितरण",
        description: "200 परिवारों को भूमि पट्टे मिले।",
        location: "वारंगल, तेलंगाना", 
        date: "2024-02-20"
      },
      {
        title: "निज़ामाबाद में न्यायालयी जीत",
        description: "भूमि हड़पने के मामले में किसानों की जीत।",
        location: "निज़ामाबाद, तेलंगाना",
        date: "2024-03-10"
      }
    ],
    last_updated: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('content').doc('daily_motivation').set(motivationData);
  console.log('Daily motivation data populated successfully!');
}

async function populateHashtags() {
  console.log('Populating hashtags collection...');
  
  const hashtags = [
    { tag: 'भूमिअधिकार', count: 0, category: 'land_rights' },
    { tag: 'किसानन्याय', count: 0, category: 'farmer_justice' },
    { tag: 'पट्टावितरण', count: 0, category: 'patta_distribution' },
    { tag: 'तेलंगानाकिसान', count: 0, category: 'telangana_farmers' },
    { tag: 'भूमिसंघर्ष', count: 0, category: 'land_struggle' },
    { tag: 'न्यायालयीजीत', count: 0, category: 'court_victory' },
    { tag: 'सामुदायिकशक्ति', count: 0, category: 'community_power' },
    { tag: 'कृषिनीति', count: 0, category: 'agriculture_policy' },
    { tag: 'ग्रामीणविकास', count: 0, category: 'rural_development' },
    { tag: 'सामाजिकन्याय', count: 0, category: 'social_justice' }
  ];

  const batch = db.batch();
  hashtags.forEach((hashtag, index) => {
    const ref = db.collection('hashtags').doc(`hashtag_${index + 1}`);
    batch.set(ref, {
      ...hashtag,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  await batch.commit();
  console.log('Hashtags populated successfully!');
}

async function populateAnalytics() {
  console.log('Populating analytics collection...');
  
  // Create a sample analytics document
  const analyticsData = {
    total_users: 0,
    total_posts: 0,
    total_stories: 0,
    total_comments: 0,
    total_likes: 0,
    active_users_today: 0,
    active_users_week: 0,
    active_users_month: 0,
    last_updated: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('analytics').doc('global_stats').set(analyticsData);
  console.log('Analytics data populated successfully!');
}

async function main() {
  try {
    await populateDailyMotivation();
    await populateHashtags();
    await populateAnalytics();
    console.log('All collections populated successfully!');
    process.exit(0);
  } catch (error) {
    console.error('Error populating collections:', error);
    process.exit(1);
  }
}

main();
