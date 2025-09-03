import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

/// Exception thrown when analytics and reporting operations fail
class AnalyticsReportingException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const AnalyticsReportingException(this.message, [this.code = 'ANALYTICS_REPORTING_FAILED', this.context]);
  
  @override
  String toString() => 'AnalyticsReportingException: $message';
}

/// Service for analytics and reporting functionality
class AnalyticsReportingService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Track referral conversion rate by time period
  static Future<Map<String, dynamic>> getReferralConversionRates({
    required DateTime startDate,
    required DateTime endDate,
    String period = 'daily', // daily, weekly, monthly
  }) async {
    try {
      final referrals = await _firestore
          .collection('referrals')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      // Free app model: Count all user registrations as conversions
      final conversions = await _firestore
          .collection('users')
          .where('registrationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('registrationDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      final periodData = <String, Map<String, int>>{};
      
      // Process referrals by period
      for (final doc in referrals.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final periodKey = _getPeriodKey(createdAt, period);
        
        periodData[periodKey] ??= {'referrals': 0, 'conversions': 0};
        periodData[periodKey]!['referrals'] = periodData[periodKey]!['referrals']! + 1;
      }
      
      // Process conversions by period
      for (final doc in conversions.docs) {
        final data = doc.data();
        final registrationDate = (data['registrationDate'] as Timestamp).toDate();
        final periodKey = _getPeriodKey(registrationDate, period);
        
        periodData[periodKey] ??= {'referrals': 0, 'conversions': 0};
        periodData[periodKey]!['conversions'] = periodData[periodKey]!['conversions']! + 1;
      }
      
      // Calculate conversion rates
      final conversionRates = <String, double>{};
      for (final entry in periodData.entries) {
        final referrals = entry.value['referrals']!;
        final conversions = entry.value['conversions']!;
        conversionRates[entry.key] = referrals > 0 ? (conversions / referrals) * 100 : 0.0;
      }
      
      return {
        'period': period,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'periodData': periodData,
        'conversionRates': conversionRates,
        'totalReferrals': referrals.docs.length,
        'totalConversions': conversions.docs.length,
        'overallConversionRate': referrals.docs.isNotEmpty
            ? (conversions.docs.length / referrals.docs.length) * 100
            : 0.0,
      };
    } catch (e) {
      throw AnalyticsReportingException(
        'Failed to get referral conversion rates: $e',
        'CONVERSION_RATES_FAILED',
        {'startDate': startDate, 'endDate': endDate, 'period': period}
      );
    }
  }
  
  /// Get geographic distribution analytics for referrals
  static Future<Map<String, dynamic>> getGeographicDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('users');
      
      if (startDate != null) {
        query = query.where('registrationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('registrationDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final users = await query.get();
      
      final countryDistribution = <String, int>{};
      final cityDistribution = <String, int>{};
      final regionDistribution = <String, int>{};
      
      for (final doc in users.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final location = data['location'] as Map<String, dynamic>?;
        
        if (location != null) {
          final country = location['country'] as String? ?? 'Unknown';
          final city = location['city'] as String? ?? 'Unknown';
          final region = location['region'] as String? ?? 'Unknown';
          
          countryDistribution[country] = (countryDistribution[country] ?? 0) + 1;
          cityDistribution[city] = (cityDistribution[city] ?? 0) + 1;
          regionDistribution[region] = (regionDistribution[region] ?? 0) + 1;
        } else {
          countryDistribution['Unknown'] = (countryDistribution['Unknown'] ?? 0) + 1;
          cityDistribution['Unknown'] = (cityDistribution['Unknown'] ?? 0) + 1;
          regionDistribution['Unknown'] = (regionDistribution['Unknown'] ?? 0) + 1;
        }
      }
      
      return {
        'totalUsers': users.docs.length,
        'countryDistribution': countryDistribution,
        'cityDistribution': cityDistribution,
        'regionDistribution': regionDistribution,
        'topCountries': _getTopEntries(countryDistribution, 10),
        'topCities': _getTopEntries(cityDistribution, 10),
        'topRegions': _getTopEntries(regionDistribution, 10),
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };
    } catch (e) {
      throw AnalyticsReportingException(
        'Failed to get geographic distribution: $e',
        'GEOGRAPHIC_DISTRIBUTION_FAILED',
        {'startDate': startDate, 'endDate': endDate}
      );
    }
  }
  
  /// Measure referral link click-through rates
  static Future<Map<String, dynamic>> getReferralLinkClickThroughRates({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('referral_clicks')
          .where('referrerId', isEqualTo: userId);
      
      if (startDate != null) {
        query = query.where('clickedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('clickedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final clicks = await query.get();
      
      // Get actual registrations from these clicks
      final registrations = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .get();
      
      final clicksBySource = <String, int>{};
      final clicksByDate = <String, int>{};
      
      for (final doc in clicks.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final source = data['source'] as String? ?? 'direct';
        final clickedAt = (data['clickedAt'] as Timestamp).toDate();
        final dateKey = _getPeriodKey(clickedAt, 'daily');
        
        clicksBySource[source] = (clicksBySource[source] ?? 0) + 1;
        clicksByDate[dateKey] = (clicksByDate[dateKey] ?? 0) + 1;
      }
      
      final clickThroughRate = clicks.docs.isNotEmpty
          ? (registrations.docs.length / clicks.docs.length) * 100
          : 0.0;
      
      return {
        'userId': userId,
        'totalClicks': clicks.docs.length,
        'totalRegistrations': registrations.docs.length,
        'clickThroughRate': clickThroughRate,
        'clicksBySource': clicksBySource,
        'clicksByDate': clicksByDate,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };
    } catch (e) {
      throw AnalyticsReportingException(
        'Failed to get click-through rates: $e',
        'CLICK_THROUGH_RATES_FAILED',
        {'userId': userId, 'startDate': startDate, 'endDate': endDate}
      );
    }
  }
  
  /// Calculate viral coefficient and network effects
  static Future<Map<String, dynamic>> getViralCoefficientAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('users');
      
      if (startDate != null) {
        query = query.where('registrationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('registrationDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final users = await query.get();
      
      int totalUsers = users.docs.length;
      int referredUsers = 0;
      int totalReferrals = 0;
      final generationData = <int, int>{}; // generation -> count
      
      for (final doc in users.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final referredBy = data['referredBy'] as String?;
        final directReferrals = data['directReferrals'] as int? ?? 0;
        
        if (referredBy != null) {
          referredUsers++;
        }
        
        totalReferrals += directReferrals;
        
        // Calculate generation (depth in referral tree)
        final generation = await _calculateUserGeneration(doc.id);
        generationData[generation] = (generationData[generation] ?? 0) + 1;
      }
      
      // Viral coefficient = average number of referrals per user
      final viralCoefficient = totalUsers > 0 ? totalReferrals / totalUsers : 0.0;
      
      // Network effect metrics
      final referralRate = totalUsers > 0 ? (referredUsers / totalUsers) * 100 : 0.0;
      final averageReferralsPerUser = totalUsers > 0 ? totalReferrals / totalUsers : 0.0;
      
      return {
        'totalUsers': totalUsers,
        'referredUsers': referredUsers,
        'organicUsers': totalUsers - referredUsers,
        'totalReferrals': totalReferrals,
        'viralCoefficient': viralCoefficient,
        'referralRate': referralRate,
        'averageReferralsPerUser': averageReferralsPerUser,
        'generationDistribution': generationData,
        'networkDepth': generationData.keys.isNotEmpty ? generationData.keys.reduce((a, b) => a > b ? a : b) : 0,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };
    } catch (e) {
      throw AnalyticsReportingException(
        'Failed to calculate viral coefficient: $e',
        'VIRAL_COEFFICIENT_FAILED',
        {'startDate': startDate, 'endDate': endDate}
      );
    }
  }
  
  /// Get real-time dashboard metrics
  static Future<Map<String, dynamic>> getRealTimeDashboardMetrics() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeek = today.subtract(Duration(days: now.weekday - 1));
      final thisMonth = DateTime(now.year, now.month, 1);
      
      // Get today's metrics
      final todayUsers = await _getUserCountForPeriod(today, now);
      final yesterdayUsers = await _getUserCountForPeriod(yesterday, today);
      final thisWeekUsers = await _getUserCountForPeriod(thisWeek, now);
      final thisMonthUsers = await _getUserCountForPeriod(thisMonth, now);
      
      // Get conversion metrics
      final todayConversions = await _getConversionCountForPeriod(today, now);
      final yesterdayConversions = await _getConversionCountForPeriod(yesterday, today);
      
      // Calculate growth rates
      final dailyGrowthRate = yesterdayUsers > 0 
          ? ((todayUsers - yesterdayUsers) / yesterdayUsers) * 100 
          : 0.0;
      
      return {
        'timestamp': now.toIso8601String(),
        'today': {
          'newUsers': todayUsers,
          'conversions': todayConversions,
          'conversionRate': todayUsers > 0 ? (todayConversions / todayUsers) * 100 : 0.0,
        },
        'yesterday': {
          'newUsers': yesterdayUsers,
          'conversions': yesterdayConversions,
          'conversionRate': yesterdayUsers > 0 ? (yesterdayConversions / yesterdayUsers) * 100 : 0.0,
        },
        'thisWeek': {
          'newUsers': thisWeekUsers,
        },
        'thisMonth': {
          'newUsers': thisMonthUsers,
        },
        'growth': {
          'dailyGrowthRate': dailyGrowthRate,
        },
      };
    } catch (e) {
      throw AnalyticsReportingException(
        'Failed to get real-time dashboard metrics: $e',
        'REAL_TIME_METRICS_FAILED'
      );
    }
  }
  
  /// Export referral data to CSV format
  static Future<String> exportReferralDataToCsv({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? userIds,
  }) async {
    try {
      Query query = _firestore.collection('users');
      
      if (startDate != null) {
        query = query.where('registrationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('registrationDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      if (userIds != null && userIds.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereIn: userIds);
      }
      
      final users = await query.get();
      
      // CSV headers
      final headers = [
        'User ID',
        'Full Name',
        'Email',
        'Referral Code',
        'Referred By',
        'Registration Date',
        'Membership Paid',
        'Direct Referrals',
        'Active Direct Referrals',
        'Team Size',
        'Active Team Size',
        'Current Role',
        'Location Country',
        'Location City',
      ];
      
      final rows = <List<String>>[headers];
      
      for (final doc in users.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final location = data['location'] as Map<String, dynamic>?;
        
        rows.add([
          doc.id,
          data['fullName'] ?? '',
          data['email'] ?? '',
          data['referralCode'] ?? '',
          data['referredBy'] ?? '',
          data['registrationDate'] != null 
              ? (data['registrationDate'] as Timestamp).toDate().toIso8601String()
              : '',
          (data['membershipPaid'] ?? false).toString(),
          (data['directReferrals'] ?? 0).toString(),
          (data['activeDirectReferrals'] ?? 0).toString(),
          (data['teamSize'] ?? 0).toString(),
          (data['activeTeamSize'] ?? 0).toString(),
          data['currentRole'] ?? '',
          location?['country'] ?? '',
          location?['city'] ?? '',
        ]);
      }
      
      final csv = _convertToCsv(rows);
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/referral_data_$timestamp.csv');
      await file.writeAsString(csv);
      
      return file.path;
    } catch (e) {
      throw AnalyticsReportingException(
        'Failed to export referral data to CSV: $e',
        'CSV_EXPORT_FAILED',
        {'startDate': startDate, 'endDate': endDate, 'userIds': userIds}
      );
    }
  }
  
  /// Export analytics report to JSON format
  static Future<String> exportAnalyticsReportToJson({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final conversionRates = await getReferralConversionRates(
        startDate: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        endDate: endDate ?? DateTime.now(),
      );
      
      final geographicDistribution = await getGeographicDistribution(
        startDate: startDate,
        endDate: endDate,
      );
      
      final viralCoefficient = await getViralCoefficientAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      
      final realTimeMetrics = await getRealTimeDashboardMetrics();
      
      final report = {
        'generatedAt': DateTime.now().toIso8601String(),
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
        'conversionRates': conversionRates,
        'geographicDistribution': geographicDistribution,
        'viralCoefficient': viralCoefficient,
        'realTimeMetrics': realTimeMetrics,
      };
      
      final json = jsonEncode(report);
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/analytics_report_$timestamp.json');
      await file.writeAsString(json);
      
      return file.path;
    } catch (e) {
      throw AnalyticsReportingException(
        'Failed to export analytics report to JSON: $e',
        'JSON_EXPORT_FAILED',
        {'startDate': startDate, 'endDate': endDate}
      );
    }
  }
  
  /// Helper method to get period key for grouping
  static String _getPeriodKey(DateTime date, String period) {
    switch (period) {
      case 'daily':
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case 'weekly':
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        return '${weekStart.year}-W${_getWeekOfYear(weekStart)}';
      case 'monthly':
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
      default:
        return date.toIso8601String().split('T')[0];
    }
  }
  
  /// Helper method to get week of year
  static int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }
  
  /// Helper method to get top entries from a map
  static List<Map<String, dynamic>> _getTopEntries(Map<String, int> data, int limit) {
    final entries = data.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    
    return entries.take(limit).map((entry) => {
      'name': entry.key,
      'count': entry.value,
    }).toList();
  }
  
  /// Helper method to calculate user generation in referral tree
  static Future<int> _calculateUserGeneration(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;
      
      final userData = userDoc.data()!;
      final referredBy = userData['referredBy'] as String?;
      
      if (referredBy == null) {
        return 0; // Root user
      }
      
      return 1 + await _calculateUserGeneration(referredBy);
    } catch (e) {
      return 0; // Default to 0 on error
    }
  }
  
  /// Helper method to get user count for a specific period
  static Future<int> _getUserCountForPeriod(DateTime start, DateTime end) async {
    final query = await _firestore
        .collection('users')
        .where('registrationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('registrationDate', isLessThan: Timestamp.fromDate(end))
        .get();
    
    return query.docs.length;
  }
  
  /// Helper method to get conversion count for a specific period
  static Future<int> _getConversionCountForPeriod(DateTime start, DateTime end) async {
    final query = await _firestore
        .collection('users')
        .where('registrationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('registrationDate', isLessThan: Timestamp.fromDate(end))
        // Free app model: Count all registrations, not just paid ones
        .get();

    return query.docs.length;
  }

  /// Helper method to convert list of lists to CSV format
  static String _convertToCsv(List<List<String>> rows) {
    final buffer = StringBuffer();

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      for (int j = 0; j < row.length; j++) {
        final cell = row[j];

        // Escape quotes and wrap in quotes if necessary
        if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
          buffer.write('"${cell.replaceAll('"', '""')}"');
        } else {
          buffer.write(cell);
        }

        if (j < row.length - 1) {
          buffer.write(',');
        }
      }

      if (i < rows.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
