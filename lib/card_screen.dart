import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../main.dart';

class CardsScreen extends StatefulWidget {
  final int folderId;
  final String folderName;

  const CardsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<Map<String, dynamic>> _cardsInFolder = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    final cards = await dbHelper.getCardsByFolderId(widget.folderId);
    setState(() {
      _cardsInFolder = cards;
      _isLoading = false;
    });
  }

  Future<void> _showAddCardDialog() async {
    // Get available cards for this suit
    final availableCards = await dbHelper.getUnassignedCardsBySuit(widget.folderName);

    if (availableCards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No more cards available for this suit!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check folder limit before showing dialog
    final currentCount = _cardsInFolder.length;
    if (currentCount >= 6) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Folder Full'),
            content: const Text('This folder can only hold 6 cards.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      final selectedCard = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select a Card'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableCards.length,
              itemBuilder: (context, index) {
                final card = availableCards[index];
                final cardName = card[DatabaseHelper.columnCardName];
                final imageUrl = card[DatabaseHelper.columnCardImageUrl];

                return ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 60,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported);
                      },
                    ),
                  ),
                  title: Text(cardName),
                  onTap: () => Navigator.pop(context, card),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedCard != null) {
        await _addCardToFolder(selectedCard);
      }
    }
  }

  Future<void> _addCardToFolder(Map<String, dynamic> card) async {
    final cardId = card[DatabaseHelper.columnCardId] as int;
    
    await dbHelper.assignCardToFolder(cardId, widget.folderId);
    await _loadCards();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${card[DatabaseHelper.columnCardName]} added to ${widget.folderName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeCard(Map<String, dynamic> card) async {
    final cardId = card[DatabaseHelper.columnCardId] as int;
    final cardName = card[DatabaseHelper.columnCardName];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Card'),
        content: Text('Remove $cardName from this folder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Check minimum card requirement
      if (_cardsInFolder.length <= 3) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cannot Remove Card'),
              content: const Text('You need at least 3 cards in this folder.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await dbHelper.removeCardFromFolder(cardId);
      await _loadCards();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$cardName removed from ${widget.folderName}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _deleteCard(Map<String, dynamic> card) async {
    final cardId = card[DatabaseHelper.columnCardId] as int;
    final cardName = card[DatabaseHelper.columnCardName];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Permanently delete $cardName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dbHelper.deleteCard(cardId);
      await _loadCards();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$cardName deleted permanently'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getSuitColor() {
    if (widget.folderName == 'Hearts' || widget.folderName == 'Diamonds') {
      return Colors.red;
    } else {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        centerTitle: true,
        backgroundColor: _getSuitColor().withOpacity(0.1),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Card count info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _cardsInFolder.length < 3
                      ? Colors.orange[100]
                      : _cardsInFolder.length >= 6
                          ? Colors.blue[100]
                          : Colors.green[100],
                  child: Text(
                    _cardsInFolder.length < 3
                        ? 'Warning: You need at least 3 cards in this folder (Current: ${_cardsInFolder.length})'
                        : _cardsInFolder.length >= 6
                            ? 'Folder is full (6/6 cards)'
                            : '${_cardsInFolder.length} card${_cardsInFolder.length != 1 ? 's' : ''} in folder (Maximum: 6)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Cards grid
                Expanded(
                  child: _cardsInFolder.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.style_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No cards in this folder',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _showAddCardDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Cards'),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.7,
                          ),
                          itemCount: _cardsInFolder.length,
                          itemBuilder: (context, index) {
                            final card = _cardsInFolder[index];
                            final cardName = card[DatabaseHelper.columnCardName];
                            final imageUrl = card[DatabaseHelper.columnCardImageUrl];

                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              size: 48,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      cardName,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _getSuitColor(),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: Colors.orange,
                                        iconSize: 20,
                                        onPressed: () => _removeCard(card),
                                        tooltip: 'Remove from folder',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        iconSize: 20,
                                        onPressed: () => _deleteCard(card),
                                        tooltip: 'Delete permanently',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCardDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Card')
      ),
    );
  }
}