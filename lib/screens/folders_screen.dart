import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../main.dart';
import '../screens/card_screen.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Map<String, dynamic>> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
    });

    final folders = await dbHelper.getAllFolders();
    setState(() {
      _folders = folders;
      _isLoading = false;
    });
  }

  Future<int> _getCardCount(int folderId) async {
    return await dbHelper.getCardCountInFolder(folderId);
  }

  Future<String?> _getFirstCardImage(int folderId) async {
    final card = await dbHelper.getFirstCardInFolder(folderId);
    return card?[DatabaseHelper.columnCardImageUrl];
  }

  Color _getSuitColor(String folderName) {
    if (folderName == 'Hearts' || folderName == 'Diamonds') {
      return Colors.red;
    } else {
      return Colors.black;
    }
  }

  String _getSuitSymbol(String folderName) {
  switch (folderName) {
    case 'Hearts':
      return '\u2665';  // Unicode: U+2665
    case 'Diamonds':
      return '\u2666';  // Unicode: U+2666
    case 'Spades':
      return '\u2660';  // Unicode: U+2660
    case 'Clubs':
      return '\u2663';  // Unicode: U+2663
    default:
      return '📁';
  }
}

  IconData _getSuitIcon(String folderName) {
    switch (folderName) {
      case 'Hearts':
        return Icons.favorite;
      case 'Diamonds':
        return Icons.diamond;
      case 'Spades':
        return Icons.spa;
      case 'Clubs':
        return Icons.filter_vintage; 
      default:
        return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Organizer'),
        centerTitle: true,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? const Center(
                  child: Text(
                    'No folders found',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFolders,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final folder = _folders[index];
                      final folderId = folder[DatabaseHelper.columnFolderId] as int;
                      final folderName = folder[DatabaseHelper.columnFolderName] as String;

                      return FutureBuilder<int>(
                        future: _getCardCount(folderId),
                        builder: (context, snapshot) {
                          final cardCount = snapshot.data ?? 0;

                          return FutureBuilder<String?>(
                            future: _getFirstCardImage(folderId),
                            builder: (context, imageSnapshot) {
                              final imageUrl = imageSnapshot.data;

                              return Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CardsScreen(
                                          folderId: folderId,
                                          folderName: folderName,
                                        ),
                                      ),
                                    );
                                    _loadFolders(); // Refresh after returning
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Card preview or icon
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: imageUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Icon(
                                                        _getSuitIcon(folderName),
                                                        size: 64,
                                                        color: _getSuitColor(folderName),
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Text(
                                                  _getSuitSymbol(folderName),
                                                  style: TextStyle(
                                                    fontSize: 64,
                                                    color: _getSuitColor(folderName),
                                                  )
                                                  
                                                ),
                                        ),
                                      ),
                                      // Folder name
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          folderName,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _getSuitColor(folderName),
                                          ),
                                        ),
                                      ),
                                      // Card count
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Text(
                                          '$cardCount card${cardCount != 1 ? 's' : ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
