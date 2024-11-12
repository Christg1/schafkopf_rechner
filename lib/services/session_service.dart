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

  // Create new session
  Future<String> createSession({
    required List<String> players,
    required double baseValue,
    required int initialDealer,
  }) async {
    final sessionDoc = await _db.collection('sessions').add({
      'date': FieldValue.serverTimestamp(),
      'players': players,
      'baseValue': baseValue, // Store as euros
      'rounds': [],
      'playerBalances': Map.fromIterables(
        players, 
        List.filled(players.length, 0)
      ),
      'currentDealer': initialDealer,
      'isActive': true,
    });

    // Create or update player documents for statistics
    for (String player in players) {
      // Use normalized name as document ID to prevent duplicates
      final docId = player.toLowerCase();
      await _db.collection('players').doc(docId).set({
        'name': player,  // Keep original case for display
        'totalGames': FieldValue.increment(0),
        'gamesWon': FieldValue.increment(0),
        'totalEarnings': 0.0,
        'gameTypeStats': {},
      }, SetOptions(merge: true));
    }

    return sessionDoc.id;
  }

  // Add round to session
  Future<void> addRound(String sessionId, GameRound round) async {
    try {
      final sessionRef = _db.collection('sessions').doc(sessionId);
      final sessionDoc = await sessionRef.get();
      final session = Session.fromFirestore(sessionDoc);
      
      // Add client-side timestamp to make each round unique
      final roundData = round.toFirestore();
      roundData['timestamp'] = Timestamp.now();
      
      // Calculate new balances for this session
      final newBalances = BalanceCalculator.calculateNewBalances(
        currentBalances: session.playerBalances,
        round: round,
        players: session.players,
      );

      // Update session with new balances
      await sessionRef.update({
        'rounds': FieldValue.arrayUnion([roundData]),
        'playerBalances': newBalances,
        'currentDealer': (session.currentDealer + 1) % session.players.length,
        'isActive': true,
      });

      // Update lifetime statistics for each player
      for (String playerName in session.players) {
        final playerRef = _db.collection('players').doc(playerName);
        
        await playerRef.update({
          'totalEarnings': FieldValue.increment(newBalances[playerName] ?? 0.0),
          'gamesParticipated': FieldValue.increment(1),
          if (playerName == round.mainPlayer) ... {
            'gamesPlayed': FieldValue.increment(1),
            'gamesWon': FieldValue.increment(round.isWon ? 1 : 0),
            'gameTypeStats.${round.gameType.name}': FieldValue.increment(1),
          },
        });
      }

    } catch (e) {
      rethrow;
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

  // End session
  Future<void> endSession(String sessionId) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to end session: $e');
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