import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';
import '../models/game_round.dart';
import '../utils/balance_calculator.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Make sure we're properly initializing Firebase
  SessionService() {
    // Optional: Add any initialization if needed
  }

  // Create new session with initial balances of 0
  Future<String> createSession({
    required List<String> players,
    required double baseValue,
    required int initialDealer,
  }) async {
    // Validate player count
    if (players.length < 3 || players.length > 4) {
      throw Exception('Invalid number of players (must be 3 or 4)');
    }

    final sessionDoc = await _db.collection('sessions').add({
      'date': FieldValue.serverTimestamp(),
      'players': players,
      'baseValue': baseValue,
      'rounds': [],
      'playerBalances': Map.fromIterables(players, List.filled(players.length, 0.0)),
      'currentDealer': initialDealer,
      'isActive': true,
    });

    return sessionDoc.id;
  }

  // Add round and update balances
  Future<void> addRound(String sessionId, GameRound round) async {
    try {
      final sessionRef = _db.collection('sessions').doc(sessionId);
      final sessionDoc = await sessionRef.get();
      final session = Session.fromFirestore(sessionDoc);
      
      // Add round
      final roundData = round.toFirestore();
      
      // Get updated session with new round
      final updatedSession = Session(
        id: session.id,
        players: session.players,
        baseValue: session.baseValue,
        rounds: [...session.rounds, round],
        currentDealer: (session.currentDealer + 1) % session.players.length,
        isActive: session.isActive,
        date: session.date,
      );

      // Update with new balances from getter
      await sessionRef.update({
        'rounds': FieldValue.arrayUnion([roundData]),
        'playerBalances': updatedSession.playerBalances,
        'currentDealer': updatedSession.currentDealer,
      });
    } catch (e) {
      rethrow;
    }
  }

  // End session and update player totals
  Future<void> endSession(String sessionId) async {
    final sessionRef = _db.collection('sessions').doc(sessionId);
    final sessionDoc = await sessionRef.get();
    final session = Session.fromFirestore(sessionDoc);

    // Get final balances
    final finalBalances = session.playerBalances;

    // Update player totals
    for (var entry in finalBalances.entries) {
      final playerRef = _db.collection('players').doc(entry.key.toLowerCase());
      await playerRef.update({
        'totalEarnings': FieldValue.increment(entry.value),
      });
    }

    // Mark session as inactive
    await sessionRef.update({
      'isActive': false,
      'endDate': Timestamp.now(),
    });
  }

  // Fix any inconsistencies
  Future<void> fixAllBalances() async {
    // Fix sessions
    final sessionsSnapshot = await _db.collection('sessions').get();
    for (var doc in sessionsSnapshot.docs) {
      final session = Session.fromFirestore(doc);
      await doc.reference.update({
        'playerBalances': session.playerBalances,
      });
    }

    // Fix player totals
    Map<String, double> totalEarnings = {};
    
    // Calculate totals from all completed sessions
    for (var doc in sessionsSnapshot.docs) {
      final session = Session.fromFirestore(doc);
      if (!session.isActive) {
        final balances = session.playerBalances;
        for (var entry in balances.entries) {
          totalEarnings[entry.key] = (totalEarnings[entry.key] ?? 0) + entry.value;
        }
      }
    }

    // Update player documents
    for (var entry in totalEarnings.entries) {
      final playerRef = _db.collection('players').doc(entry.key.toLowerCase());
      await playerRef.update({
        'totalEarnings': entry.value,
      });
    }
  }

  // Get active session
  Stream<Session?> getActiveSession() {
    return _db.collection('sessions')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.isEmpty ? null : Session.fromFirestore(snapshot.docs.first));
  }

  // Add a method to verify totalEarnings
  Future<void> verifyTotalEarnings() async {
    try {
      // Get all sessions
      final sessionsSnapshot = await _db.collection('sessions').get();
      
      // Track running totals for each player
      Map<String, double> calculatedTotals = {};
      
      // Calculate totals from all sessions
      for (var sessionDoc in sessionsSnapshot.docs) {
        final session = Session.fromFirestore(sessionDoc);
        if (!session.isActive) {  // Only count completed sessions
          session.playerBalances.forEach((player, balance) {
            calculatedTotals[player] = (calculatedTotals[player] ?? 0) + balance;
          });
        }
      }
      
      // Update all players with correct totals
      for (var entry in calculatedTotals.entries) {
        final playerRef = _db.collection('players').doc(entry.key.toLowerCase());
        await playerRef.update({
          'totalEarnings': entry.value,
        });
      }
    } catch (e) {
      throw Exception('Failed to verify total earnings: $e');
    }
  }

  // Add this method
  Stream<Session> getSession(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => Session.fromFirestore(doc));
  }
} 