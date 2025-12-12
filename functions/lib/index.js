"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.migrateConversations = exports.getUnreadCount = exports.getUserConversations = exports.sendEmergencyBroadcast = exports.createAnonymousReport = exports.markConversationAsRead = exports.sendMessage = exports.createConversation = exports.onMessageCreated = exports.triggerRolePromotionCheck = exports.automaticRolePromotion = exports.sendEmergencyAlert = exports.sendCampaignNotification = exports.sendSocialNotification = exports.sendReferralNotification = exports.sendWelcomeNotification = exports.processNotificationQueue = exports.bulkModerateUsers = exports.moderateContent = exports.getAdminAuditLogs = exports.validateAdminAccess = exports.sendAdminAlert = exports.flagSuspiciousReferrals = exports.logAdminAction = exports.revokeAdminRole = exports.assignAdminRole = exports.createUserRegistry = exports.checkPhone = exports.registerUserProfile = exports.getMyReferralStats = exports.bulkFixReferralConsistency = exports.fixReferralCodeConsistency = exports.ensureReferralCode = exports.fixOrphanedUsers = exports.autoPromoteUser = exports.processReferral = void 0;
// functions/src/index.ts
const admin = __importStar(require("firebase-admin"));
// Initialize Firebase Admin SDK
admin.initializeApp();
// Export referral system functions
var referral_system_1 = require("./referral-system");
Object.defineProperty(exports, "processReferral", { enumerable: true, get: function () { return referral_system_1.processReferral; } });
Object.defineProperty(exports, "autoPromoteUser", { enumerable: true, get: function () { return referral_system_1.autoPromoteUser; } });
Object.defineProperty(exports, "fixOrphanedUsers", { enumerable: true, get: function () { return referral_system_1.fixOrphanedUsers; } });
Object.defineProperty(exports, "ensureReferralCode", { enumerable: true, get: function () { return referral_system_1.ensureReferralCode; } });
Object.defineProperty(exports, "fixReferralCodeConsistency", { enumerable: true, get: function () { return referral_system_1.fixReferralCodeConsistency; } });
Object.defineProperty(exports, "bulkFixReferralConsistency", { enumerable: true, get: function () { return referral_system_1.bulkFixReferralConsistency; } });
Object.defineProperty(exports, "getMyReferralStats", { enumerable: true, get: function () { return referral_system_1.getMyReferralStats; } });
Object.defineProperty(exports, "registerUserProfile", { enumerable: true, get: function () { return referral_system_1.registerUserProfile; } });
Object.defineProperty(exports, "checkPhone", { enumerable: true, get: function () { return referral_system_1.checkPhone; } });
Object.defineProperty(exports, "createUserRegistry", { enumerable: true, get: function () { return referral_system_1.createUserRegistry; } });
// Export admin system functions
var admin_system_1 = require("./admin-system");
Object.defineProperty(exports, "assignAdminRole", { enumerable: true, get: function () { return admin_system_1.assignAdminRole; } });
Object.defineProperty(exports, "revokeAdminRole", { enumerable: true, get: function () { return admin_system_1.revokeAdminRole; } });
Object.defineProperty(exports, "logAdminAction", { enumerable: true, get: function () { return admin_system_1.logAdminAction; } });
Object.defineProperty(exports, "flagSuspiciousReferrals", { enumerable: true, get: function () { return admin_system_1.flagSuspiciousReferrals; } });
Object.defineProperty(exports, "sendAdminAlert", { enumerable: true, get: function () { return admin_system_1.sendAdminAlert; } });
Object.defineProperty(exports, "validateAdminAccess", { enumerable: true, get: function () { return admin_system_1.validateAdminAccess; } });
Object.defineProperty(exports, "getAdminAuditLogs", { enumerable: true, get: function () { return admin_system_1.getAdminAuditLogs; } });
Object.defineProperty(exports, "moderateContent", { enumerable: true, get: function () { return admin_system_1.moderateContent; } });
Object.defineProperty(exports, "bulkModerateUsers", { enumerable: true, get: function () { return admin_system_1.bulkModerateUsers; } });
// Export notification system functions
var notifications_1 = require("./notifications");
Object.defineProperty(exports, "processNotificationQueue", { enumerable: true, get: function () { return notifications_1.processNotificationQueue; } });
Object.defineProperty(exports, "sendWelcomeNotification", { enumerable: true, get: function () { return notifications_1.sendWelcomeNotification; } });
Object.defineProperty(exports, "sendReferralNotification", { enumerable: true, get: function () { return notifications_1.sendReferralNotification; } });
Object.defineProperty(exports, "sendSocialNotification", { enumerable: true, get: function () { return notifications_1.sendSocialNotification; } });
Object.defineProperty(exports, "sendCampaignNotification", { enumerable: true, get: function () { return notifications_1.sendCampaignNotification; } });
Object.defineProperty(exports, "sendEmergencyAlert", { enumerable: true, get: function () { return notifications_1.sendEmergencyAlert; } });
// Export automatic role promotion functions
var automatic_role_promotion_1 = require("./automatic-role-promotion");
Object.defineProperty(exports, "automaticRolePromotion", { enumerable: true, get: function () { return automatic_role_promotion_1.automaticRolePromotion; } });
Object.defineProperty(exports, "triggerRolePromotionCheck", { enumerable: true, get: function () { return automatic_role_promotion_1.triggerRolePromotionCheck; } });
// Export messaging system functions
var messaging_1 = require("./messaging");
Object.defineProperty(exports, "onMessageCreated", { enumerable: true, get: function () { return messaging_1.onMessageCreated; } });
Object.defineProperty(exports, "createConversation", { enumerable: true, get: function () { return messaging_1.createConversation; } });
Object.defineProperty(exports, "sendMessage", { enumerable: true, get: function () { return messaging_1.sendMessage; } });
Object.defineProperty(exports, "markConversationAsRead", { enumerable: true, get: function () { return messaging_1.markConversationAsRead; } });
Object.defineProperty(exports, "createAnonymousReport", { enumerable: true, get: function () { return messaging_1.createAnonymousReport; } });
Object.defineProperty(exports, "sendEmergencyBroadcast", { enumerable: true, get: function () { return messaging_1.sendEmergencyBroadcast; } });
Object.defineProperty(exports, "getUserConversations", { enumerable: true, get: function () { return messaging_1.getUserConversations; } });
Object.defineProperty(exports, "getUnreadCount", { enumerable: true, get: function () { return messaging_1.getUnreadCount; } });
// Export migration functions
var migrate_conversations_1 = require("./migrate-conversations");
Object.defineProperty(exports, "migrateConversations", { enumerable: true, get: function () { return migrate_conversations_1.migrateConversations; } });
//# sourceMappingURL=index.js.map