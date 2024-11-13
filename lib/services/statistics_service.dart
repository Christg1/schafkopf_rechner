import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';
import '../models/game_round.dart';
import '../models/statistics_data.dart';
import '../utils/statistics_calculator.dart';

class StatisticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Single stream for all statistics
  Stream<StatisticsData> getStatisticsStream() {
    return _db.collection('sessions')
        .snapshots()
        .map((snapshot) {
          print('Got ${snapshot.docs.length} sessions from Firebase');
          try {
            final sessions = snapshot.docs
                .map((doc) {
                  print('Processing session ${doc.id}');
                  return Session.fromFirestore(doc);
                })
                .toList();
                
            print('Successfully processed all sessions');
            return StatisticsData.fromSessions(sessions);
          } catch (e, stackTrace) {
            print('Error processing sessions: $e');
            print(stackTrace);
            rethrow;
          }
        });
  }

  // Method to verify and fix data consistency
  Future<void> verifyAndFixData() async {
    // First get all sessions outside the transaction
    final QuerySnapshot<Map<String, dynamic>> sessionsSnapshot = 
        await _db.collection('sessions').get();
    
    final sessions = sessionsSnapshot.docs
        .map((doc) => Session.fromFirestore(doc))
        .toList();
    
    final stats = StatisticsData.fromSessions(sessions);
    
    // Then use transaction only for updating player stats
    return _db.runTransaction((transaction) async {
      for (final playerStat in stats.playerStats.entries) {
        final playerRef = _db.collection('players').doc(playerStat.key);
        final playerDoc = await transaction.get(playerRef);
        
        if (playerDoc.exists) {
          transaction.update(playerRef, playerStat.value.toFirestore());
        } else {
          transaction.set(playerRef, playerStat.value.toFirestore());
        }
      }
    });
  }

  // Helper method to get a single session
  Future<Session?> getSession(String sessionId) async {
    final doc = await _db.collection('sessions').doc(sessionId).get();
    return doc.exists ? Session.fromFirestore(doc) : null;
  }

  // Helper method to get all sessions
  Future<List<Session>> getAllSessions() async {
    final snapshot = await _db.collection('sessions').get();
    return snapshot.docs
        .map((doc) => Session.fromFirestore(doc))
        .toList();
  }
} 