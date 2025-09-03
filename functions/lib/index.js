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
exports.bulkModerateUsers = exports.moderateContent = exports.getAdminAuditLogs = exports.validateAdminAccess = exports.sendAdminAlert = exports.flagSuspiciousReferrals = exports.logAdminAction = exports.revokeAdminRole = exports.assignAdminRole = exports.createUserRegistry = exports.checkPhone = exports.registerUserProfile = exports.getMyReferralStats = exports.bulkFixReferralConsistency = exports.fixReferralCodeConsistency = exports.ensureReferralCode = exports.fixOrphanedUsers = exports.autoPromoteUser = exports.processReferral = void 0;
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
// Export existing functions (if any)
// Add your production-ready functions here
//# sourceMappingURL=index.js.map