import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';
import '../models/game_round.dart';
import '../utils/balance_calculator.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    final batch = _db.batch();
    
    // Get current session data
    final sessionDoc = await _db.collection('sessions').doc(sessionId).get();
    final session = Session.fromFirestore(sessionDoc);
    
    // Calculate new balances
    Map<String, double> newBalances = BalanceCalculator.calculateNewBalances(
      currentBalances: session.playerBalances,
      round: round,
      players: session.players,
    );
    
    // Update session
    batch.update(_db.collection('sessions').doc(sessionId), {
      'rounds': FieldValue.arrayUnion([round.toFirestore()]),
      'playerBalances': newBalances,
      'currentDealer': (session.currentDealer + 1) % 4,
    });

    // Update player statistics
    _updatePlayerStats(round, batch, session.players);

    await batch.commit();
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

  void _updatePlayerStats(GameRound round, WriteBatch batch, List<String> sessionPlayers) {
    final playerRef = _db.collection('players');
    
    // Update main player statistics
    batch.update(playerRef.doc(round.mainPlayer.toLowerCase()), {
      'gamesPlayed': FieldValue.increment(1),
      'gamesWon': FieldValue.increment(round.isWon ? 1 : 0),
      'totalEarnings': FieldValue.increment(round.value * (round.isWon ? 1 : -1)),
      'gameTypeStats.${round.gameType.name}': FieldValue.increment(1),
      'gamesParticipated': FieldValue.increment(1),
    });

    // Update all other players' participation and earnings
    for (String player in sessionPlayers) {
      if (player != round.mainPlayer) {
        double earnings = 0;
        bool isPartner = round.partner == player;
        bool isWinner = (isPartner && round.isWon) || (!isPartner && !round.isWon);
        earnings = round.value * (isWinner ? 1 : -1);

        batch.update(playerRef.doc(player.toLowerCase()), {
          'gamesParticipated': FieldValue.increment(1),
          'totalEarnings': FieldValue.increment(earnings),
        });
      }
    }
  }
} 