import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "CardOrganizer.db";
  static const _databaseVersion = 1;

  // Folders table
  static const tableFolders = 'folders';
  static const columnFolderId = 'id';
  static const columnFolderName = 'name';
  static const columnFolderTimestamp = 'timestamp';

  // Cards table
  static const tableCards = 'cards';
  static const columnCardId = 'id';
  static const columnCardName = 'name';
  static const columnCardSuit = 'suit';
  static const columnCardImageUrl = 'image_url';
  static const columnCardFolderId = 'folder_id';

  late Database _db;

  // Open/create database
  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // Create tables and prepopulate data
  Future _onCreate(Database db, int version) async {
    // Create folders table
    await db.execute('''
      CREATE TABLE $tableFolders (
        $columnFolderId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnFolderName TEXT NOT NULL,
        $columnFolderTimestamp TEXT NOT NULL
      )
    ''');

    // Create cards table
    await db.execute('''
      CREATE TABLE $tableCards (
        $columnCardId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnCardName TEXT NOT NULL,
        $columnCardSuit TEXT NOT NULL,
        $columnCardImageUrl TEXT NOT NULL,
        $columnCardFolderId INTEGER,
        FOREIGN KEY ($columnCardFolderId) REFERENCES $tableFolders ($columnFolderId)
      )
    ''');

    // Prepopulate folders
    await _prepopulateFolders(db);
    
    // Prepopulate cards
    await _prepopulateCards(db);
  }

  // Prepopulate the four suit folders
  Future<void> _prepopulateFolders(Database db) async {
    final suits = ['Hearts', 'Spades', 'Diamonds', 'Clubs'];
    final timestamp = DateTime.now().toIso8601String();

    for (var suit in suits) {
      await db.insert(tableFolders, {
        columnFolderName: suit,
        columnFolderTimestamp: timestamp,
      });
    }
  }

  // Prepopulate all cards (1-13 for each suit)
  Future<void> _prepopulateCards(Database db) async {
    final suits = ['Hearts', 'Spades', 'Diamonds', 'Clubs'];
    final cardNames = [
      'Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 
      'Jack', 'Queen', 'King'
    ];

    for (var suit in suits) {
      for (int i = 0; i < cardNames.length; i++) {
        final cardName = '${cardNames[i]} of $suit';
        // Using placeholder URLs - you can replace with actual card image URLs
        final imageUrl = 'https://deckofcardsapi.com/static/img/${_getCardCode(cardNames[i], suit)}.png';
        
        await db.insert(tableCards, {
          columnCardName: cardName,
          columnCardSuit: suit,
          columnCardImageUrl: imageUrl,
          columnCardFolderId: null, // Initially unassigned
        });
      }
    }
  }

  // Helper to get card code for image URL
  String _getCardCode(String name, String suit) {
    String value;
    switch (name) {
      case 'Ace':
        value = 'A';
        break;
      case 'Jack':
        value = 'J';
        break;
      case 'Queen':
        value = 'Q';
        break;
      case 'King':
        value = 'K';
        break;
      default:
        value = name;
    }

    String suitCode;
    switch (suit) {
      case 'Hearts':
        suitCode = 'H';
        break;
      case 'Spades':
        suitCode = 'S';
        break;
      case 'Diamonds':
        suitCode = 'D';
        break;
      case 'Clubs':
        suitCode = 'C';
        break;
      default:
        suitCode = 'H';
    }

    return '$value$suitCode';
  }

  // ===== FOLDER OPERATIONS =====

  // Get all folders
  Future<List<Map<String, dynamic>>> getAllFolders() async {
    return await _db.query(tableFolders);
  }

  // Get folder by ID
  Future<Map<String, dynamic>?> getFolderById(int id) async {
    final result = await _db.query(
      tableFolders,
      where: '$columnFolderId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Update folder
  Future<int> updateFolder(Map<String, dynamic> folder) async {
    final int id = folder[columnFolderId];
    return await _db.update(
      tableFolders,
      folder,
      where: '$columnFolderId = ?',
      whereArgs: [id],
    );
  }

  // Delete folder (and optionally its cards)
  Future<int> deleteFolder(int id) async {
    // First, unassign all cards from this folder
    await _db.update(
      tableCards,
      {columnCardFolderId: null},
      where: '$columnCardFolderId = ?',
      whereArgs: [id],
    );
    
    return await _db.delete(
      tableFolders,
      where: '$columnFolderId = ?',
      whereArgs: [id],
    );
  }

  // ===== CARD OPERATIONS =====

  // Get all cards
  Future<List<Map<String, dynamic>>> getAllCards() async {
    return await _db.query(tableCards);
  }

  // Get cards by folder ID
  Future<List<Map<String, dynamic>>> getCardsByFolderId(int folderId) async {
    return await _db.query(
      tableCards,
      where: '$columnCardFolderId = ?',
      whereArgs: [folderId],
    );
  }

  // Get unassigned cards (not in any folder)
  Future<List<Map<String, dynamic>>> getUnassignedCards() async {
    return await _db.query(
      tableCards,
      where: '$columnCardFolderId IS NULL',
    );
  }

  // Get unassigned cards by suit
  Future<List<Map<String, dynamic>>> getUnassignedCardsBySuit(String suit) async {
    return await _db.query(
      tableCards,
      where: '$columnCardFolderId IS NULL AND $columnCardSuit = ?',
      whereArgs: [suit],
    );
  }

  // Count cards in folder
  Future<int> getCardCountInFolder(int folderId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM $tableCards WHERE $columnCardFolderId = ?',
      [folderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Add card to folder
  Future<int> assignCardToFolder(int cardId, int folderId) async {
    return await _db.update(
      tableCards,
      {columnCardFolderId: folderId},
      where: '$columnCardId = ?',
      whereArgs: [cardId],
    );
  }

  // Update card
  Future<int> updateCard(Map<String, dynamic> card) async {
    final int id = card[columnCardId];
    return await _db.update(
      tableCards,
      card,
      where: '$columnCardId = ?',
      whereArgs: [id],
    );
  }

  // Remove card from folder
  Future<int> removeCardFromFolder(int cardId) async {
    return await _db.update(
      tableCards,
      {columnCardFolderId: null},
      where: '$columnCardId = ?',
      whereArgs: [cardId],
    );
  }

  // Delete card
  Future<int> deleteCard(int id) async {
    return await _db.delete(
      tableCards,
      where: '$columnCardId = ?',
      whereArgs: [id],
    );
  }

  // Get first card in folder (for preview)
  Future<Map<String, dynamic>?> getFirstCardInFolder(int folderId) async {
    final result = await _db.query(
      tableCards,
      where: '$columnCardFolderId = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
}