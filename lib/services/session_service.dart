import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schafkopf_rechner/models/game_types.dart';
import 'package:schafkopf_rechner/models/player.dart';
import '../models/session.dart';
import '../models/game_round.dart';
import '../utils/balance_calculator.dart';
import '../models/statistics_data.dart';

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
    final sessionRef = _db.collection('sessions').doc(sessionId);
    final sessionDoc = await sessionRef.get();
    final session = Session.fromFirestore(sessionDoc);

    final newBalances = BalanceCalculator.calculateNewBalances(
      currentBalances: session.playerBalances,
      round: round,
      players: session.players,
    );

    final batch = _db.batch();

    // Update session
    batch.update(sessionRef, {
      'rounds': FieldValue.arrayUnion([round.toFirestore()]),
      'playerBalances': newBalances,
      'currentDealer': (session.currentDealer + 1) % session.players.length,
    });

    // Update player stats - Use FieldValue.increment for atomic updates
    for (final player in session.players) {
      final playerRef = _db.collection('players').doc(player.toLowerCase());
      
      batch.set(playerRef, {
        'name': player,
        'gamesParticipated': FieldValue.increment(1),
        'gamesPlayed': FieldValue.increment(player == round.mainPlayer ? 1 : 0),
        'gamesWon': FieldValue.increment(
          player == round.mainPlayer && round.isWon ? 1 : 0
        ),
        'totalEarnings': FieldValue.increment(newBalances[player]! - (session.playerBalances[player] ?? 0)),  // Fix: Calculate the difference
        'gameTypeStats.${round.gameType.name}': FieldValue.increment(
          player == round.mainPlayer ? 1 : 0
        ),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // End session and update player totals
  Future<void> endSession(String sessionId) async {
    // Remove this method or make it only mark the session as inactive
    final sessionRef = _db.collection('sessions').doc(sessionId);
    
    // Just mark as inactive, don't update player stats again
    await sessionRef.update({'isActive': false});
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