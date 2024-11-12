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

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final session = Session.fromFirestore(sessionDoc);
      
      // Calculate new balances
      final newBalances = BalanceCalculator.calculateNewBalances(
        currentBalances: session.playerBalances,
        round: round,
        players: session.players,
      );

      // Update session
      await sessionRef.update({
        'rounds': FieldValue.arrayUnion([round.toFirestore()]),
        'playerBalances': newBalances,
        'currentDealer': (session.currentDealer + 1) % session.players.length,
      });

      // Update player statistics
      for (String playerName in session.players) {
        final playerRef = _db.collection('players').doc(playerName);
        final playerDoc = await playerRef.get();
        final currentData = playerDoc.data() ?? {};
        
        // Get current game type stats
        Map<String, int> gameTypeStats = Map<String, int>.from(currentData['gameTypeStats'] ?? {});
        
        // Update game type count for the main player
        if (playerName == round.mainPlayer) {
          final gameTypeName = round.gameType.name;
          gameTypeStats[gameTypeName] = (gameTypeStats[gameTypeName] ?? 0) + 1;
        }

        // Calculate balance change for this player
        final oldBalance = session.playerBalances[playerName] ?? 0.0;
        final newBalance = newBalances[playerName] ?? 0.0;
        final balanceChange = newBalance - oldBalance;

        await playerRef.set({
          'name': playerName,
          'gamesParticipated': (currentData['gamesParticipated'] ?? 0) + 1,
          'gamesPlayed': (currentData['gamesPlayed'] ?? 0) + (playerName == round.mainPlayer ? 1 : 0),
          'gamesWon': (currentData['gamesWon'] ?? 0) + 
              (playerName == round.mainPlayer && round.isWon ? 1 : 0),
          'totalEarnings': (currentData['totalEarnings'] ?? 0.0) + balanceChange,
          'gameTypeStats': gameTypeStats,
        }, SetOptions(merge: true));
      }

    } catch (e) {
      print('Error in addRound: $e');
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
    await _db.collection('sessions').doc(sessionId).update({
      'isActive': false,
    });
  }

  Future<void> _updatePlayerStats(GameRound round, WriteBatch batch, List<String> players) async {
    final playersRef = _db.collection('players');

    for (String playerName in players) {
      final playerDoc = await playersRef.doc(playerName).get();
      final Map<String, dynamic> currentData = playerDoc.data() ?? {};
      
      // Get current values or default to 0
      double currentEarnings = (currentData['totalEarnings'] ?? 0.0).toDouble();
      
      // Add the new balance from this session
      double newBalance = currentEarnings;
      
      // Update total earnings by adding the new balance from this session
      if (playerDoc.exists) {
        newBalance += round.value;  // Add the new balance
      }

      batch.set(playersRef.doc(playerName), {
        'name': playerName,
        'totalEarnings': newBalance,
        'gamesParticipated': (currentData['gamesParticipated'] ?? 0) + 1,
        'gamesPlayed': (currentData['gamesPlayed'] ?? 0) + (playerName == round.mainPlayer ? 1 : 0),
        'gamesWon': (currentData['gamesWon'] ?? 0) + 
            (playerName == round.mainPlayer && round.isWon ? 1 : 0),
      }, SetOptions(merge: true));
    }
  }
} 