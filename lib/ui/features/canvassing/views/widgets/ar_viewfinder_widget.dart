import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Renders a real-time camera viewfinder HUD overlay for AR canvassing.
class ArViewfinderWidget extends StatefulWidget {
  /// Creates an AR viewfinder widget.
  const ArViewfinderWidget({
    super.key,
    required this.detectedPlaneCount,
    required this.isTracking,
    this.headingDegrees = 0.0,
    this.activeFloor = 0,
    this.stepCount = 0,
  });

  /// The count of structural planes recognized by ARCore.
  final int detectedPlaneCount;

  /// Whether the AR tracking session is active.
  final bool isTracking;

  /// Current device heading in degrees.
  final double headingDegrees;

  /// The currently active floor being surveyed.
  final int activeFloor;

  /// Number of PDR steps counted.
  final int stepCount;

  @override
  State<ArViewfinderWidget> createState() => _ArViewfinderWidgetState();
}

class _ArViewfinderWidgetState extends State<ArViewfinderWidget> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'No camera sensor detected on device');
        }
        return;
      }

      // Pick back-facing camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Camera access issue: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _isCameraReady = false;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview Background or High-Contrast Fallback
          if (_isCameraReady && _cameraController != null)
            _buildCameraPreview()
          else
            _buildFallbackBackground(),

          // 2. AR Perspective Horizon & Floor Grid
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ArPerspectiveGridPainter(),
              ),
            ),
          ),

          // 3. Central AR Viewfinder Reticle & Feature Points
          IgnorePointer(
            child: Center(
              child: CustomPaint(
                size: const Size(240, 240),
                painter: _ReticlePainter(headingDegrees: widget.headingDegrees),
              ),
            ),
          ),

          // 4. Top Status Header (AR Tracking, Planes, Floor)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Live Camera / AR Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isCameraReady ? AppColors.emeraldGreen : AppColors.amberWarning,
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCameraReady ? Icons.videocam : Icons.videocam_off,
                          color: _isCameraReady ? AppColors.emeraldGreen : AppColors.amberWarning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCameraReady
                              ? 'AR Camera Live • ${widget.detectedPlaneCount} Planes'
                              : (_cameraError ?? 'Initializing Camera...'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floor & Step Counter Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cobaltBlue.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cyanAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers, color: AppColors.cyanAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Floor ${widget.activeFloor}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Guidance Card above bottom action sheet
          Positioned(
            bottom: 230,
            left: 20,
            right: 20,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk, color: AppColors.cyanAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isCameraReady
                            ? 'Point camera down hallways and walk forward. Tap "Add Room" or "Stairs" as you reach them.'
                            : 'Camera initializing. You can still walk and record waypoints with phone sensors.',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.cyanAccent),
            const SizedBox(height: 16),
            Text(
              _cameraError ?? 'Connecting Camera Feed...',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (_cameraError != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Camera'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArPerspectiveGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.12)
      ..strokeWidth = 1.0;

    final horizonY = size.height * 0.52;
    final centerX = size.width / 2;

    // Horizon line
    final horizonPaint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.3)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), horizonPaint);

    // Radiating ground perspective lines
    for (var i = -4; i <= 4; i++) {
      final start = Offset(centerX + i * 26.0, horizonY);
      final end = Offset(centerX + i * (size.width / 3.2), size.height);
      canvas.drawLine(start, end, gridPaint);
    }

    // Horizontal grid distance lines
    for (var y = horizonY + 30; y < size.height; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.headingDegrees});

  final double headingDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyanAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const cornerLength = 28.0;

    // Top-left bracket
    canvas.drawLine(Offset.zero, const Offset(cornerLength, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, cornerLength), paint);

    // Top-right bracket
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left bracket
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-right bracket
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);

    // Center targeting reticle
    final center = Offset(size.width / 2, size.height / 2);
    final dotPaint = Paint()
      ..color = AppColors.cyanAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, dotPaint);

    const crossLength = 12.0;
    canvas.drawLine(center - const Offset(crossLength, 0), center + const Offset(crossLength, 0), paint);
    canvas.drawLine(center - const Offset(0, crossLength), center + const Offset(0, crossLength), paint);

    // Simulated AR Feature tracking points (floating around center)
    final featurePaint = Paint()
      ..color = AppColors.emeraldGreen.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final offsets = [
      Offset(center.dx - 50, center.dy - 35),
      Offset(center.dx + 65, center.dy - 20),
      Offset(center.dx - 30, center.dy + 45),
      Offset(center.dx + 40, center.dy + 55),
      Offset(center.dx - 70, center.dy + 15),
    ];

    for (final pt in offsets) {
      canvas.drawCircle(pt, 2.5, featurePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) =>
      oldDelegate.headingDegrees != headingDegrees;
}
