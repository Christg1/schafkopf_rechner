import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/game_round.dart';

class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create new game
  Future<String> createGame(List<String> players) async {
    final docRef = await _db.collection('games').add({
      'date': Timestamp.now(),
      'players': players,
      'rounds': [],
    });
    return docRef.id;
  }

  // Add round to game
  Future<void> addRound(String gameId, GameRound round) async {
    await _db.collection('games').doc(gameId).update({
      'rounds': FieldValue.arrayUnion([round.toFirestore()]),
      'currentDealer': FieldValue.increment(1),
    });
  }

  // Get game by ID
  Stream<Game> getGame(String gameId) {
    return _db.collection('games')
        .doc(gameId)
        .snapshots()
        .map((doc) => Game.fromFirestore(doc));
  }

  // Get all games
  Stream<List<Game>> getAllGames() {
    return _db.collection('games')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList());
  }
} 