import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/calendar_sync_service.dart';

class EpisodeCalendarSyncDialog extends StatefulWidget {
  final Map<String, dynamic> animeData;
  final List<Map<String, dynamic>> episodes;

  const EpisodeCalendarSyncDialog({
    super.key,
    required this.animeData,
    required this.episodes,
  });

  @override
  State<EpisodeCalendarSyncDialog> createState() => _EpisodeCalendarSyncDialogState();
}

class _EpisodeCalendarSyncDialogState extends State<EpisodeCalendarSyncDialog> {
  final CalendarSyncService _calendarService = CalendarSyncService.instance;
  
  List<Calendar> _availableCalendars = [];
  Calendar? _selectedCalendar;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0); // 8:00 PM default
  List<Map<String, dynamic>> _futureEpisodes = [];
  List<Map<String, dynamic>> _selectedEpisodes = [];
  bool _isLoading = false;
  bool _isLoadingCalendars = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeFutureEpisodes();
    _loadCalendars();
  }

  void _initializeFutureEpisodes() {
    final now = DateTime.now();
    
    // Filter episodes to include today and future episodes only
    _futureEpisodes = widget.episodes.where((episode) {
      if (episode['aired'] == null) return false;
      
      try {
        final airDate = DateTime.parse(episode['aired']);
        // Include episodes from today onwards
        return airDate.isAfter(now.subtract(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
    
    // Sort by air date
    _futureEpisodes.sort((a, b) {
      final dateA = DateTime.parse(a['aired']);
      final dateB = DateTime.parse(b['aired']);
      return dateA.compareTo(dateB);
    });
  }

  Future<void> _loadCalendars() async {
    try {
      setState(() {
        _isLoadingCalendars = true;
        _error = null;
      });

      final hasPermissions = await _calendarService.requestPermissions();
      if (!hasPermissions) {
        setState(() {
          _error = 'Calendar permissions are required to sync episodes.';
          _isLoadingCalendars = false;
        });
        return;
      }

      final calendars = await _calendarService.getAvailableCalendars();
      setState(() {
        _availableCalendars = calendars;
        if (calendars.isNotEmpty) {
          _selectedCalendar = calendars.first;
        }
        _isLoadingCalendars = false;
      });

      if (calendars.isEmpty) {
        setState(() {
          _error = 'No writable calendars found on your device.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load calendars: $e';
        _isLoadingCalendars = false;
      });
    }
  }

  Future<void> _syncEpisodes() async {
    if (_selectedCalendar == null || _selectedEpisodes.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      int successfulEvents = 0;
      int totalEvents = _selectedEpisodes.length;

      for (final episode in _selectedEpisodes) {
        final success = await _createEpisodeEvent(episode);
        if (success) successfulEvents++;
      }

      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successfulEvents == totalEvents
                ? 'Successfully synced $successfulEvents episode(s) to your calendar!'
                : 'Synced $successfulEvents of $totalEvents episode(s) to your calendar.',
          ),
          backgroundColor: successfulEvents > 0 ? Colors.green : null,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to sync episodes: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _createEpisodeEvent(Map<String, dynamic> episode) async {
    try {
      final airDate = DateTime.parse(episode['aired']);
      final eventDateTime = DateTime(
        airDate.year,
        airDate.month,
        airDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final animeTitle = widget.animeData['title'] ?? 'Unknown Anime';
      final episodeTitle = episode['title'] ?? 'Episode ${episode['malId']}';
      
      final eventTitle = '🎌 $animeTitle - $episodeTitle';
      final eventDescription = _buildEpisodeEventDescription(episode);

      final event = Event(
        _selectedCalendar!.id,
        title: eventTitle,
        description: eventDescription,
        start: tz.TZDateTime.from(eventDateTime, tz.local),
        end: tz.TZDateTime.from(eventDateTime.add(const Duration(minutes: 30)), tz.local), // 30-minute events
        allDay: false,
        url: widget.animeData['url'],
      );

      final result = await DeviceCalendarPlugin().createOrUpdateEvent(event);
      return result?.isSuccess == true;
    } catch (e) {
      debugPrint('❌ [EpisodeCalendarSync] Failed to create event for episode ${episode['malId']}: $e');
      return false;
    }
  }

  String _buildEpisodeEventDescription(Map<String, dynamic> episode) {
    final buffer = StringBuffer();
    final animeTitle = widget.animeData['title'] ?? 'Unknown Anime';
    final episodeTitle = episode['title'] ?? 'Episode ${episode['malId']}';
    
    buffer.writeln('🎌 Anime Episode Reminder');
    buffer.writeln('');
    buffer.writeln('📺 Anime: $animeTitle');
    buffer.writeln('🎬 Episode: $episodeTitle');
    
    if (episode['score'] != null) {
      buffer.writeln('⭐ Score: ${episode['score']}/10');
    }
    
    if (widget.animeData['synopsis'] != null) {
      final synopsis = widget.animeData['synopsis'].toString();
      final truncatedSynopsis = synopsis.length > 100 
          ? '${synopsis.substring(0, 100)}...' 
          : synopsis;
      buffer.writeln('');
      buffer.writeln('📖 Synopsis: $truncatedSynopsis');
    }
    
    buffer.writeln('');
    buffer.writeln('📱 Created by Hanimo app');
    
    return buffer.toString();
  }

  String _formatEpisodeForDropdown(Map<String, dynamic> episode) {
    final episodeNum = episode['malId'] ?? 0;
    final title = episode['title'] ?? 'Episode $episodeNum';
    final airDate = DateTime.parse(episode['aired']);
    final formattedDate = '${airDate.day}/${airDate.month}/${airDate.year}';
    
    return 'Ep $episodeNum: $title ($formattedDate)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.98,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sync Episodes to Calendar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Anime title
                Text(
                  widget.animeData['title'] ?? 'Unknown Anime',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                if (_isLoadingCalendars) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Center(child: Text('Loading calendars...')),
                ] else if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_availableCalendars.isEmpty)
                    ElevatedButton(
                      onPressed: _loadCalendars,
                      child: const Text('Retry'),
                    ),
                ] else if (_futureEpisodes.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_view_week,
                          size: 48,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Future Episodes',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This anime has no upcoming episodes to sync.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Episodes selection
                  Text(
                    'Select Episodes (${_futureEpisodes.length} available)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Multi-select dropdown for episodes
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selection summary
                        Text(
                          _selectedEpisodes.isEmpty 
                              ? 'No episodes selected'
                              : '${_selectedEpisodes.length} episode(s) selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Quick action buttons
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedEpisodes = List.from(_futureEpisodes);
                                });
                              },
                              icon: const Icon(Icons.select_all, size: 16),
                              label: const Text('All'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedEpisodes.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('None'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Episodes list with checkboxes
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            itemCount: _futureEpisodes.length,
                            itemBuilder: (context, index) {
                              final episode = _futureEpisodes[index];
                              final isSelected = _selectedEpisodes.contains(episode);
                              
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedEpisodes.add(episode);
                                    } else {
                                      _selectedEpisodes.remove(episode);
                                    }
                                  });
                                },
                                title: Text(
                                  _formatEpisodeForDropdown(episode),
                                  style: theme.textTheme.bodySmall,
                                ),
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Calendar selection
                  Text(
                    'Calendar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Calendar>(
                    value: _selectedCalendar,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _availableCalendars.map((calendar) {
                      return DropdownMenuItem<Calendar>(
                        value: calendar,
                        child: Text(
                          calendar.name ?? 'Unknown Calendar',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: (Calendar? newValue) {
                      setState(() {
                        _selectedCalendar = newValue;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Time selection
                  Text(
                    'Notification Time',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null) {
                        setState(() {
                          _selectedTime = time;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTime.format(context),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_selectedEpisodes.isEmpty || _selectedCalendar == null || _isLoading)
                              ? null
                              : _syncEpisodes,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text('Sync ${_selectedEpisodes.length} Episode(s)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 