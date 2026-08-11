import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing a scanned RFID tag
class ScannedTag {
  final String id;
  final String tid;
  final String epc;
  final String timeStamp;
  final String chipModel;
  final int readCount;
  final int rssi;

  ScannedTag({
    required this.id,
    required this.tid,
    required this.epc,
    required this.timeStamp,
    required this.chipModel,
    required this.readCount,
    required this.rssi,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tid': tid,
        'epc': epc,
        'timeStamp': timeStamp,
        'chipModel': chipModel,
        'readCount': readCount,
        'rssi': rssi,
      };

  factory ScannedTag.fromJson(Map<String, dynamic> json) => ScannedTag(
        id: json['id'] as String,
        tid: json['tid'] as String,
        epc: json['epc'] as String,
        timeStamp: json['timeStamp'] as String,
        chipModel: json['chipModel'] as String,
        readCount: json['readCount'] as int,
        rssi: json['rssi'] as int,
      );

  /// Create a ScannedTag from a raw RFID string (for mock scanning)
  factory ScannedTag.fromRfid({
    required String rfid,
    required int index,
    required String timestamp,
  }) {
    final random = Random();
    return ScannedTag(
      id: (index + 1).toString().padLeft(2, '0'),
      tid: rfid,
      epc: 'Tag ${index + 1}',
      timeStamp: timestamp,
      chipModel: 'Mock Reader',
      readCount: 1,
      rssi: -(random.nextInt(50) + 180),
    );
  }

  /// Create a ScannedTag from platform (C72) tag map: epc, tid, rssi, readCount, timestamp, model.
  factory ScannedTag.fromPlatformTag(
    Map<String, dynamic> map, {
    required int index,
  }) {
    return ScannedTag(
      id: (index + 1).toString().padLeft(2, '0'),
      tid: map['tid'] as String? ?? '',
      epc: map['epc'] as String? ?? '',
      timeStamp: map['timestamp'] as String? ?? '',
      chipModel: map['model'] as String? ?? 'C72',
      readCount: (map['readCount'] as num?)?.toInt() ?? 1,
      rssi: (map['rssi'] as num?)?.toInt() ?? -80,
    );
  }
}

/// Model representing a scan session
class ScanSession {
  final String sessionId;
  final String startTime;
  final String? endTime;
  final int? rssi;
  final List<ScannedTag> tags;
  final bool isSynced;
  final int? conferenceId;
  final List<String> conferenceEpcs;

  ScanSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    this.rssi,
    required this.tags,
    this.isSynced = false,
    this.conferenceId,
    this.conferenceEpcs = const [],
  });

  int get tagCount => tags.length;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'startTime': startTime,
        'endTime': endTime,
        'rssi': rssi,
        'tags': tags.map((t) => t.toJson()).toList(),
        'isSynced': isSynced,
        'conferenceId': conferenceId,
        'conferenceEpcs': conferenceEpcs,
      };

  factory ScanSession.fromJson(Map<String, dynamic> json) => ScanSession(
        sessionId: json['sessionId'] as String,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String?,
        rssi: json['rssi'] as int? ?? -80,
        tags: (json['tags'] as List<dynamic>)
            .map((t) => ScannedTag.fromJson(t as Map<String, dynamic>))
            .toList(),
        isSynced: json['isSynced'] as bool? ?? false,
        conferenceId: json['conferenceId'] as int?,
        conferenceEpcs: (json['conferenceEpcs'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  ScanSession copyWith({
    String? sessionId,
    String? startTime,
    String? endTime,
    int? rssi,
    List<ScannedTag>? tags,
    bool? isSynced,
    int? conferenceId,
    List<String>? conferenceEpcs,
  }) {
    return ScanSession(
      sessionId: sessionId ?? this.sessionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      rssi: rssi ?? this.rssi,
      tags: tags ?? this.tags,
      isSynced: isSynced ?? this.isSynced,
      conferenceId: conferenceId ?? this.conferenceId,
      conferenceEpcs: conferenceEpcs ?? this.conferenceEpcs,
    );
  }
}

/// Service to manage scan sessions with local storage
class ScanSessionService extends ChangeNotifier {
  static final ScanSessionService _instance = ScanSessionService._internal();
  factory ScanSessionService() => _instance;
  ScanSessionService._internal() {
    _loadFromStorage();
  }

  static const String _sessionsKey = 'scan_sessions';

  List<ScanSession> _sessions = [];
  bool _isLoaded = false;

  List<ScanSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoaded => _isLoaded;

  /// Get sessions sorted by date (newest first)
  List<ScanSession> get sortedSessions {
    final sorted = List<ScanSession>.from(_sessions);
    sorted.sort((a, b) => _parseDateTime(b.startTime).compareTo(_parseDateTime(a.startTime)));
    return sorted;
  }

  static DateTime _parseDateTime(String formatted) {
    // Format: dd/MM/yyyy HH:mm:ss
    final parts = formatted.split(' ');
    final dateParts = parts[0].split('/');
    final timeParts = parts.length > 1 ? parts[1].split(':') : ['0', '0', '0'];
    return DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[1]),
      int.parse(dateParts[0]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getString(_sessionsKey);

    if (sessionsJson != null) {
      final List<dynamic> sessionsList = jsonDecode(sessionsJson);
      _sessions = sessionsList
          .map((json) => ScanSession.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson =
        jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, sessionsJson);
  }

  /// Add a new scan session
  Future<void> addSession(ScanSession session) async {
    _sessions.insert(0, session);
    await _saveToStorage();
    notifyListeners();
  }

  /// Get a session by ID
  ScanSession? getSession(String sessionId) {
    try {
      return _sessions.firstWhere((s) => s.sessionId == sessionId);
    } catch (e) {
      return null;
    }
  }

  /// Update a session
  Future<void> updateSession(ScanSession session) async {
    final index = _sessions.indexWhere((s) => s.sessionId == session.sessionId);
    if (index != -1) {
      _sessions[index] = session;
      await _saveToStorage();
      notifyListeners();
    }
  }

  /// Delete a session
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.sessionId == sessionId);
    await _saveToStorage();
    notifyListeners();
  }

  /// Mark session as synced
  Future<void> markAsSynced(String sessionId) async {
    final session = getSession(sessionId);
    if (session != null) {
      await updateSession(session.copyWith(isSynced: true));
    }
  }

  /// Get all unsynced sessions
  List<ScanSession> get unsyncedSessions =>
      _sessions.where((s) => !s.isSynced).toList();

  /// Generate a unique session ID
  static String generateSessionId() {
    return 'S${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Format datetime for display
  static String formatDateTime(DateTime time) {
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    final year = time.year;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }
}
