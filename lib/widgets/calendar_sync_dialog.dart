import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import '../services/calendar_sync_service.dart';

class CalendarSyncDialog extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> weeklySchedule;
  final bool showOnlyFollowed;
  final Function(int malId) isAnimeFollowed;

  const CalendarSyncDialog({
    super.key,
    required this.weeklySchedule,
    required this.showOnlyFollowed,
    required this.isAnimeFollowed,
  });

  @override
  State<CalendarSyncDialog> createState() => _CalendarSyncDialogState();
}

class _CalendarSyncDialogState extends State<CalendarSyncDialog> {
  final CalendarSyncService _calendarService = CalendarSyncService.instance;
  
  List<Calendar> _availableCalendars = [];
  Calendar? _selectedCalendar;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  Map<String, bool> _selectedDays = {};
  bool _isLoading = false;
  bool _isLoadingCalendars = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeSelectedDays();
    _loadCalendars();
  }

  void _initializeSelectedDays() {
    // Initialize all days with their anime counts
    for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
      final daySchedule = widget.weeklySchedule[day] ?? [];
      final filteredSchedule = widget.showOnlyFollowed
          ? daySchedule.where((anime) => widget.isAnimeFollowed(anime['malId'] ?? 0)).toList()
          : daySchedule;
      
      // Only enable days that have anime
      _selectedDays[day] = filteredSchedule.isNotEmpty;
    }
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
          _error = 'Calendar permissions are required to sync anime releases.';
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

  int _getAnimeCountForDay(String day) {
    final daySchedule = widget.weeklySchedule[day] ?? [];
    final filteredSchedule = widget.showOnlyFollowed
        ? daySchedule.where((anime) => widget.isAnimeFollowed(anime['malId'] ?? 0)).toList()
        : daySchedule;
    return filteredSchedule.length;
  }

  Future<void> _syncCalendar() async {
    if (_selectedCalendar == null) return;
    
    final selectedDaysList = _selectedDays.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedDaysList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day to sync.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _calendarService.syncAnimeReleases(
        calendarId: _selectedCalendar!.id!,
        weeklySchedule: widget.weeklySchedule,
        selectedDays: selectedDaysList,
        syncTime: _selectedTime,
        showOnlyFollowed: widget.showOnlyFollowed,
        isAnimeFollowed: widget.isAnimeFollowed,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully synced ${selectedDaysList.length} days to ${_selectedCalendar!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sync calendar. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing calendar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
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
                    Icons.calendar_today,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sync My Calendar',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Loading or Error State
              if (_isLoadingCalendars) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading calendars...'),
                      ],
                    ),
                  ),
                ),
              ] else if (_error != null) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCalendars,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Calendar Selection
                Text(
                  'Select Calendar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Calendar>(
                      value: _selectedCalendar,
                      isExpanded: true,
                      items: _availableCalendars.map((calendar) {
                        return DropdownMenuItem<Calendar>(
                          value: calendar,
                          child: Text(calendar.name ?? 'Unnamed Calendar'),
                        );
                      }).toList(),
                      onChanged: (calendar) {
                        setState(() {
                          _selectedCalendar = calendar;
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Time Selection
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
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedTime.format(context),
                          style: theme.textTheme.bodyLarge,
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
                
                // Days Selection
                Text(
                  'Select Days',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
                  final animeCount = _getAnimeCountForDay(day);
                  final hasAnime = animeCount > 0;
                  
                  return CheckboxListTile(
                    value: _selectedDays[day] ?? false,
                    onChanged: hasAnime ? (value) {
                      setState(() {
                        _selectedDays[day] = value ?? false;
                      });
                    } : null,
                    title: Text(
                      '$day${hasAnime ? ' ($animeCount)' : ' (0)'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasAnime 
                            ? theme.colorScheme.onSurface 
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }).toList(),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _syncCalendar,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sync Calendar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 