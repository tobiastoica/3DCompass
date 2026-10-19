import 'dart:async';
import 'dart:io';

/// Severity level for telemetry log entries.
enum LogLevel {
  /// Verbose debugging telemetry.
  debug,

  /// High-level system lifecycle events.
  info,

  /// Sensor readings (PDR steps, barometer, GPS fixes).
  sensor,

  /// Navigation pathfinding and waypoint events.
  navigation,

  /// Recoverable anomalies or sensor signal warnings.
  warning,

  /// Critical errors and unhandled exceptions.
  error,
}

/// Provides persistent asynchronous runtime logging to the mobile Downloads folder.
class FileLoggerService {
  /// Creates a file logger service.
  FileLoggerService({
    String? customLogDirectory,
    String? logFileNamePrefix,
  })  : _customLogDirectory = customLogDirectory,
        _logFileNamePrefix = logFileNamePrefix ?? '3d_compass_log';

  final String? _customLogDirectory;
  final String _logFileNamePrefix;

  File? _activeLogFile;
  IOSink? _sink;
  final List<String> _memoryBuffer = [];
  bool _isInitialized = false;

  /// Whether the file logger has initialized a file sink on disk.
  bool get isInitialized => _isInitialized;

  /// The absolute path of the active log file on the device, or `null`.
  String? get activeLogFilePath => _activeLogFile?.path;

  /// Initializes the log file in the Android Downloads folder.
  Future<String> initialize() async {
    if (_isInitialized && _activeLogFile != null) {
      return _activeLogFile!.path;
    }

    final targetDir = await _resolveDownloadDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final now = DateTime.now();
    final dateSuffix = '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final file = File('${targetDir.path}/${_logFileNamePrefix}_$dateSuffix.txt');

    _activeLogFile = file;
    _sink = file.openWrite(mode: FileMode.append);
    _isInitialized = true;

    // Header entry
    log(
      LogLevel.info,
      'LOGGER',
      '=== 3D Compass Session Started at ${now.toIso8601String()} ===',
    );
    log(
      LogLevel.info,
      'LOGGER',
      'Target log file: ${file.path}',
    );

    // Flush any pre-init logs
    for (final buffered in _memoryBuffer) {
      _sink?.writeln(buffered);
    }
    _memoryBuffer.clear();
    await _sink?.flush();

    return file.path;
  }

  /// Appends a structured log entry with [level], [category], and [message].
  void log(LogLevel level, String category, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final levelTag = level.name.toUpperCase().padRight(5);
    final entry = '[$timestamp] [$levelTag] [$category] $message';

    if (_isInitialized && _sink != null) {
      _sink!.writeln(entry);
    } else {
      _memoryBuffer.add(entry);
    }
  }

  /// Logs a pedestrian dead reckoning (PDR) step detection event.
  void logPdrStep({
    required double stepLengthMeters,
    required double headingDegrees,
    required double posX,
    required double posY,
    required double posZ,
  }) {
    log(
      LogLevel.sensor,
      'PDR',
      'Step: L=${stepLengthMeters.toStringAsFixed(2)}m, '
          'heading=${headingDegrees.toStringAsFixed(1)}°, '
          'pos=(${posX.toStringAsFixed(2)}, ${posY.toStringAsFixed(2)}, ${posZ.toStringAsFixed(2)})m',
    );
  }

  /// Logs a barometric pressure change and relative elevation update.
  void logBarometerUpdate({
    required double currentPressureHpa,
    required double relativeAltitudeMeters,
    required int floorIndex,
  }) {
    log(
      LogLevel.sensor,
      'BARO',
      'P=${currentPressureHpa.toStringAsFixed(2)}hPa, '
          'dZ=${relativeAltitudeMeters.toStringAsFixed(2)}m, '
          'Floor=$floorIndex',
    );
  }

  /// Logs an incoming faint GNSS fix and whether the EKF accepted or gated it out.
  void logGpsFix({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required bool isAccepted,
  }) {
    log(
      LogLevel.sensor,
      'GNSS',
      'Fix: ($latitude, $longitude), '
          'sigma=±${accuracyMeters.toStringAsFixed(1)}m, '
          'Status=${isAccepted ? "ACCEPTED" : "REJECTED (Multipath/Low-accuracy)"}',
    );
  }

  /// Logs a doorway check-in baseline latch event.
  void logDoorwayCheckin({
    required String entranceId,
    required String entranceName,
    required double baselinePressureHpa,
  }) {
    log(
      LogLevel.info,
      'DOORWAY',
      'Calibrated at "$entranceName" ($entranceId): '
          'P0=${baselinePressureHpa.toStringAsFixed(2)}hPa (Datum established)',
    );
  }

  /// Logs a 3D A* route computation result.
  void logRouteComputed({
    required String startNodeId,
    required String targetNodeId,
    required double totalDistanceMeters,
    required int waypointCount,
    required int elapsedMicroseconds,
  }) {
    log(
      LogLevel.navigation,
      'ROUTE',
      'Computed path $startNodeId -> $targetNodeId: '
          'dist=${totalDistanceMeters.toStringAsFixed(1)}m, '
          'waypoints=$waypointCount, '
          'time=${elapsedMicroseconds}us',
    );
  }

  /// Resolves the mobile Downloads directory across platforms.
  Future<Directory> _resolveDownloadDirectory() async {
    if (_customLogDirectory != null) {
      return Directory(_customLogDirectory);
    }

    // Primary Android external storage Downloads folder
    const androidDownloadPath = '/storage/emulated/0/Download';
    final androidDownloadDir = Directory(androidDownloadPath);
    if (await androidDownloadDir.exists()) {
      return androidDownloadDir;
    }

    // Standard fallback directory for other platforms or restricted sandbox
    final systemTemp = Directory.systemTemp;
    return Directory('${systemTemp.path}/3DCompass_Logs');
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  /// Flushes all pending entries to disk.
  Future<void> flush() async {
    await _sink?.flush();
  }

  /// Flushes and closes the active file stream.
  Future<void> dispose() async {
    await flush();
    await _sink?.close();
    _sink = null;
    _isInitialized = false;
  }
}
