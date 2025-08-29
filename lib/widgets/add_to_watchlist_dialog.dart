import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_anime_service.dart';
import '../services/followed_anime_service.dart';
import '../redux/app_state.dart';
import '../redux/actions.dart';

class AddToWatchlistDialog extends StatefulWidget {
  final String animeTitle;
  final int? totalEpisodes;
  final Map<String, dynamic>? animeData;
  final Function(Map<String, dynamic>)? onSave;
  final bool isEditMode;
  final UserAnime? currentUserAnime;

  const AddToWatchlistDialog({
    super.key,
    required this.animeTitle,
    this.totalEpisodes,
    this.animeData,
    this.onSave,
    this.isEditMode = false,
    this.currentUserAnime,
  });

  @override
  State<AddToWatchlistDialog> createState() => _AddToWatchlistDialogState();
}

class _AddToWatchlistDialogState extends State<AddToWatchlistDialog> {
  AnimeWatchStatus _selectedStatus = AnimeWatchStatus.planning; // Always default to planning
  int _watchedEpisodes = 0;
  double _userScore = 0.0;
  bool _showAdvanced = false;
  bool _isLoading = false;
  
  // Advanced fields
  final TextEditingController _notesController = TextEditingController();
  double _rewatchScore = 0.0;
  int _rewatchCount = 0;
  final TextEditingController _tagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // If in edit mode, populate fields with current data
    if (widget.isEditMode && widget.currentUserAnime != null) {
      final userAnime = widget.currentUserAnime!;
      _selectedStatus = userAnime.watchStatus;
      _watchedEpisodes = userAnime.watchedEpisodesCount;
      _userScore = userAnime.userRating ?? 0.0;
      _notesController.text = userAnime.userNotes ?? '';
    }
    
    // Ensure the selected status is available for this anime
    _validateSelectedStatus();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _validateSelectedStatus() {
    List<AnimeWatchStatus> availableStatuses = _getAvailableStatuses();
    if (!availableStatuses.contains(_selectedStatus)) {
      _selectedStatus = AnimeWatchStatus.planning; // Always fall back to planning
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.98,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.isEditMode ? 'Edit Watchlist' : 'Add to Watchlist',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Anime Name (Display only)
                  _buildSectionHeader('Anime', theme),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      widget.animeTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Status Dropdown
                  _buildSectionHeader('Status', theme),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AnimeWatchStatus>(
                        value: _selectedStatus,
                        isExpanded: true,
                        items: _getAvailableStatuses().map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(_getStatusDisplayName(status)),
                          );
                        }).toList(),
                        onChanged: (AnimeWatchStatus? newStatus) {
                          if (newStatus != null) {
                            setState(() {
                              _selectedStatus = newStatus;
                              // Reset watched episodes when changing status
                              if (newStatus != AnimeWatchStatus.watching) {
                                _watchedEpisodes = 0;
                              }
                              // Reset score when changing to planning or watching
                              if (newStatus == AnimeWatchStatus.planning || 
                                  newStatus == AnimeWatchStatus.watching) {
                                _userScore = 0.0;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  
                  // Watched Episodes (only show when status is Watching)
                  if (_selectedStatus == AnimeWatchStatus.watching) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader('Watched Episodes', theme),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _watchedEpisodes,
                          isExpanded: true,
                          items: List.generate(
                            (widget.totalEpisodes ?? 12) + 1, // +1 to include 0
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text('$index${widget.totalEpisodes != null ? ' / ${widget.totalEpisodes}' : ''}'),
                            ),
                          ),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _watchedEpisodes = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                  
                  // User Score (only show when status is Completed or Dropped)
                  if (_selectedStatus == AnimeWatchStatus.completed || 
                      _selectedStatus == AnimeWatchStatus.dropped) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader('Your Score', theme),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Score: ${_userScore.toStringAsFixed(1)}/10',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    Icons.star,
                                    color: _userScore >= (index + 1) * 2 
                                        ? Colors.amber 
                                        : Colors.grey.withOpacity(0.3),
                                    size: 20,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _userScore,
                            min: 0.0,
                            max: 10.0,
                            divisions: 100,
                            onChanged: (double value) {
                              setState(() {
                                _userScore = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Advanced Section Toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showAdvanced = !_showAdvanced;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          _showAdvanced ? Icons.expand_less : Icons.expand_more,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showAdvanced ? 'Hide Advanced' : 'Show Advanced',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Advanced Section
                  if (_showAdvanced) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notes
                          _buildSectionHeader('Notes', theme),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Add your personal notes about this anime...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Re-watch Score
                          _buildSectionHeader('Re-watch Score', theme),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${_rewatchScore.toStringAsFixed(1)}/10'),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          Icons.star,
                                          color: _rewatchScore >= (index + 1) * 2 
                                              ? Colors.amber 
                                              : Colors.grey.withOpacity(0.3),
                                          size: 16,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _rewatchScore,
                                  min: 0.0,
                                  max: 10.0,
                                  divisions: 100,
                                  onChanged: (double value) {
                                    setState(() {
                                      _rewatchScore = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Re-watch Count
                          _buildSectionHeader('Re-watch Count', theme),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _rewatchCount,
                                isExpanded: true,
                                items: List.generate(21, (index) {
                                  return DropdownMenuItem(
                                    value: index,
                                    child: Text(index == 0 ? 'Never re-watched' : '$index time${index > 1 ? 's' : ''}'),
                                  );
                                }),
                                onChanged: (int? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _rewatchCount = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Tags
                          _buildSectionHeader('Tags', theme),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tagsController,
                            decoration: InputDecoration(
                              hintText: 'Enter tags separated by commas (e.g., action, romance, must-watch)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  Column(
                    children: [
                      // Save Button (Primary with border)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleSave,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(widget.isEditMode ? 'Updating...' : 'Adding to Watchlist...'),
                                  ],
                                )
                              : Text(widget.isEditMode ? 'Update Watchlist' : 'Add to Watchlist'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Cancel/Remove Button
                      Center(
                        child: widget.isEditMode 
                            ? ElevatedButton(
                                onPressed: _isLoading ? null : _handleRemove,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Remove from Watchlist'),
                              )
                            : TextButton(
                                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                                child: Text(
                                  'Cancel',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    decoration: TextDecoration.underline,
                                    decorationColor: _isLoading 
                                        ? theme.colorScheme.onSurface.withOpacity(0.3)
                                        : theme.colorScheme.onSurface.withOpacity(0.6),
                                    color: _isLoading 
                                        ? theme.colorScheme.onSurface.withOpacity(0.3)
                                        : theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  List<AnimeWatchStatus> _getAvailableStatuses() {
    List<AnimeWatchStatus> availableStatuses = [AnimeWatchStatus.planning];
    
    // Check if anime has episodes
    bool hasEpisodes = widget.totalEpisodes != null && widget.totalEpisodes! > 0;
    
    debugPrint('🎯 [AddToWatchlistDialog] Episodes: ${widget.totalEpisodes}, hasEpisodes: $hasEpisodes');
    
    // If anime has episodes, add watching and dropped options
    if (hasEpisodes) {
      availableStatuses.add(AnimeWatchStatus.watching);
      availableStatuses.add(AnimeWatchStatus.dropped);
      
      // Check if anime is still airing
      String? animeStatus = widget.animeData?['status']?.toString().toLowerCase();
      bool isAiring = animeStatus == 'currently airing' || animeStatus == 'airing';
      
      debugPrint('🎯 [AddToWatchlistDialog] Anime status: "$animeStatus", isAiring: $isAiring');
      
      // Only add completed if anime is not currently airing
      if (!isAiring) {
        availableStatuses.add(AnimeWatchStatus.completed);
      }
    }
    
    debugPrint('🎯 [AddToWatchlistDialog] Available statuses: ${availableStatuses.map((s) => s.value).toList()}');
    
    return availableStatuses;
  }

  String _getStatusDisplayName(AnimeWatchStatus status) {
    switch (status) {
      case AnimeWatchStatus.planning:
        return 'Planning to Watch';
      case AnimeWatchStatus.watching:
        return 'Watching';
      case AnimeWatchStatus.completed:
        return 'Completed';
      case AnimeWatchStatus.dropped:
        return 'Dropped';
    }
  }

  Future<void> _handleSave() async {
    if (_isLoading) return;
    
    // Validate that we have anime data
    if (widget.animeData == null) {
      _showErrorSnackBar('Anime data is missing. Please try again.');
      return;
    }
    
    // Check if user is authenticated
    final userAnimeService = UserAnimeService();
    if (!userAnimeService.isAuthenticated) {
      _showErrorSnackBar('Please sign in to add anime to your watchlist.');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      debugPrint('💾 [AddToWatchlistDialog] Saving anime to watchlist...');
      debugPrint('   • Anime: ${widget.animeTitle}');
      debugPrint('   • Status: ${_selectedStatus.value}');
      debugPrint('   • User Score: $_userScore');
      debugPrint('   • Notes: ${_notesController.text}');
      
      // Prepare notes with additional fields if they exist
      String? combinedNotes = _buildCombinedNotes();
      
      // Calculate episodes delta for user total tracking
      int episodesDelta = 0;
      if (widget.isEditMode && widget.currentUserAnime != null) {
        // In edit mode, calculate difference from current episodes
        episodesDelta = _watchedEpisodes - widget.currentUserAnime!.watchedEpisodesCount;
      } else {
        // In add mode, all watched episodes are new
        episodesDelta = _watchedEpisodes;
      }
      
      // Use Redux to follow/update the anime
      final store = StoreProvider.of<AppState>(context);
      await store.dispatch(followAnimeAction(
        widget.animeData!,
        watchStatus: _selectedStatus,
        userRating: _userScore > 0 ? _userScore : null,
        userNotes: combinedNotes,
        watchedEpisodesCount: _watchedEpisodes,
        isUpdate: widget.isEditMode,
      ));
      
      // Update user's total episodes watched count
      if (episodesDelta != 0) {
        await _updateUserEpisodesWatched(episodesDelta);
      }
      
      debugPrint('✅ [AddToWatchlistDialog] Successfully ${widget.isEditMode ? 'updated' : 'added'} anime ${widget.isEditMode ? 'in' : 'to'} watchlist');
      
      // Close dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        _showSuccessSnackBar(widget.isEditMode 
            ? 'Updated "${widget.animeTitle}" in your watchlist!' 
            : 'Added "${widget.animeTitle}" to your watchlist!');
        
        // Call the callback if provided (for UI updates)
        if (widget.onSave != null) {
          final data = {
            'status': _selectedStatus,
            'watchedEpisodes': _watchedEpisodes,
            'userScore': _userScore,
            'notes': _notesController.text,
            'rewatchScore': _rewatchScore,
            'rewatchCount': _rewatchCount,
            'tags': _tagsController.text,
          };
          widget.onSave!(data);
        }
      }
    } catch (e) {
      debugPrint('❌ [AddToWatchlistDialog] Failed to save anime: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      String errorMessage = widget.isEditMode 
          ? 'Failed to update anime in watchlist.' 
          : 'Failed to add anime to watchlist.';
      if (e.toString().contains('already in your collection')) {
        errorMessage = 'This anime is already in your watchlist.';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = widget.isEditMode 
            ? 'Please sign in to update anime in your watchlist.'
            : 'Please sign in to add anime to your watchlist.';
      }
      
      _showErrorSnackBar(errorMessage);
    }
  }

  Future<void> _handleRemove() async {
    if (_isLoading) return;
    
    // Check if user is authenticated
    final userAnimeService = UserAnimeService();
    if (!userAnimeService.isAuthenticated) {
      _showErrorSnackBar('Please sign in to remove anime from your watchlist.');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      debugPrint('🗑️ [AddToWatchlistDialog] Removing anime from watchlist...');
      debugPrint('   • Anime: ${widget.animeTitle}');
      
      // Calculate episodes to subtract from user total
      final episodesToSubtract = widget.currentUserAnime?.watchedEpisodesCount ?? 0;
      
      // Use FollowedAnimeService to unfollow the anime
      final animeId = widget.animeData?['malId'] ?? widget.currentUserAnime?.malId;
      if (animeId != null) {
        await FollowedAnimeService.unfollowAnime(context, animeId);
        
        // Update user's total episodes watched count
        if (episodesToSubtract > 0) {
          await _updateUserEpisodesWatched(-episodesToSubtract);
        }
      }
      
      debugPrint('✅ [AddToWatchlistDialog] Successfully removed anime from watchlist');
      
      // Close dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        _showSuccessSnackBar('Removed "${widget.animeTitle}" from your watchlist!');
        
        // Call the callback if provided (for UI updates)
        if (widget.onSave != null) {
          final data = {
            'removed': true,
            'episodesSubtracted': episodesToSubtract,
          };
          widget.onSave!(data);
        }
      }
    } catch (e) {
      debugPrint('❌ [AddToWatchlistDialog] Failed to remove anime: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      _showErrorSnackBar('Failed to remove anime from watchlist.');
    }
  }

  /// Update user's total episodes watched count in Firestore
  Future<void> _updateUserEpisodesWatched(int episodesDelta) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      
      // Get current episodes watched count
      final docSnapshot = await userDoc.get();
      final currentData = docSnapshot.data() ?? {};
      final currentEpisodesWatched = currentData['episodesWatched'] ?? 0;
      
      // Calculate new total (ensure it doesn't go below 0)
      final newTotal = (currentEpisodesWatched + episodesDelta).clamp(0, double.infinity).toInt();
      
      // Update the field
      await userDoc.set({
        'episodesWatched': newTotal,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('📊 [AddToWatchlistDialog] Updated user episodes watched: $currentEpisodesWatched → $newTotal (delta: $episodesDelta)');
    } catch (e) {
      debugPrint('❌ [AddToWatchlistDialog] Failed to update user episodes watched: $e');
      // Don't rethrow - this is a secondary operation
    }
  }
  
  String? _buildCombinedNotes() {
    List<String> notesParts = [];
    
    // Add user notes
    if (_notesController.text.trim().isNotEmpty) {
      notesParts.add(_notesController.text.trim());
    }
    
    // Add advanced fields if they have values
    if (_showAdvanced) {
      if (_rewatchScore > 0) {
        notesParts.add('Re-watch Score: ${_rewatchScore.toStringAsFixed(1)}/10');
      }
      
      if (_rewatchCount > 0) {
        notesParts.add('Re-watched: $_rewatchCount time${_rewatchCount > 1 ? 's' : ''}');
      }
      
      if (_tagsController.text.trim().isNotEmpty) {
        notesParts.add('Tags: ${_tagsController.text.trim()}');
      }
    }
    
    return notesParts.isNotEmpty ? notesParts.join('\n\n') : null;
  }
  
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
} 