# 3D Compass: No-GPS Indoor 3D Navigation & Multi-Floor Compass for Android

A privacy-first, autonomous mobile application built with **Flutter & Dart** providing sub-meter 3D compass navigation and multi-story building localization **without GPS infrastructure**.

---

## Key Features

1. **Google ARCore Visual-Inertial Canvassing**:
   - Walk through a building with your phone to map rooms, corridors, stairwells, and elevators.
   - Leverages ARCore horizontal and vertical plane detection combined with walking kinematics to build a navigable 3D graph (`NavGraph3D`).
2. **100% Offline Doorway Datum Calibration**:
   - Requires **zero internet connection** or third-party weather APIs.
   - At the building entrance doorway, the user confirms their presence; the app latches the onboard hardware atmospheric pressure $P_{\text{entrance}}$ as datum $P_0$.
   - Vertical elevation $\Delta z(t)$ is computed in real time using the hypsometric formula.
3. **High-Speed Binary 3D Format (`.3dnav`)**:
   - Stores raw IEEE-754 32-bit floats and integers in contiguous memory buffers.
   - Deserializes directly into Dart `ByteData` / `Float32List` in **$< 1\text{ ms}$** with sub-millimeter geometric accuracy.
4. **Sensor-Fused Localization (7-State EKF)**:
   - Fuses **Pedestrian Dead Reckoning (PDR)** (accelerometer peak detection + Weinberg stride model), **AHRS Rotation Vector**, **Barometric Altimetry**, and **faint GNSS signals** (when near windows or atriums, filtered by horizontal accuracy gate $\sigma_{gps} \le 35\text{ m}$).
5. **3D Spatial Vector Compass HUD**:
   - Pure-Dart `CustomPainter` rendering a 3-DOF tilting vector pointer.
   - Dynamically tilts upwards or downwards if destination rooms are on different floors.
6. **3D A\* Multi-Floor Pathfinding**:
   - Computes optimal paths across floors with stair and elevator transition penalties.
   - Includes a wheelchair-accessible mode (pruning stairs).
7. **Adaptive Responsive Layout (`flutter-build-responsive-layout`)**:
   - Seamlessly adapts using `LayoutBuilder` from compact phone portrait mode to large-screen tablet/foldable split-screen HUD.

---

## Architecture Overview (Clean Architecture + MVVM)

```text
lib/
├── data/
│   ├── datasources/
│   │   ├── binary_nav_serializer.dart    # .3dnav IEEE-754 binary parser
│   │   └── building_local_storage.dart   # File persistence
│   ├── repositories/
│   │   ├── building_repository_impl.dart
│   │   ├── navigation_repository_impl.dart
│   │   └── sensor_fusion_repository_impl.dart
│   └── services/
│       ├── arcore_canvass_service.dart   # Google ARCore plane detection
│       ├── barometric_altimeter_service.dart # Offline entrance-relative pressure
│       ├── extended_kalman_filter.dart   # 7-state sensor fusion filter
│       ├── faint_gps_service.dart        # Faint GNSS listener with sigma gate
│       └── inertia_pdr_service.dart      # Peak detection & Weinberg stride PDR
├── domain/
│   ├── models/
│   │   ├── building_3d_model.dart
│   │   ├── calibration_anchor.dart
│   │   ├── coordinates_3d.dart
│   │   ├── floor_level.dart
│   │   ├── nav_edge.dart
│   │   ├── nav_graph_3d.dart
│   │   ├── nav_node.dart
│   │   ├── navigation_path.dart
│   │   ├── orientation_3d.dart
│   │   └── position_estimate.dart
│   ├── repositories/
│   │   ├── building_repository.dart
│   │   ├── navigation_repository.dart
│   │   └── sensor_fusion_repository.dart
│   └── use_cases/
│       ├── calibrate_entrance_use_case.dart
│       ├── canvass_building_use_case.dart
│       ├── compute_shortest_3d_path_use_case.dart
│       └── track_live_position_use_case.dart
├── ui/
│   ├── core/
│   │   ├── constants/app_breakpoints.dart
│   │   ├── theme/app_colors.dart
│   │   └── widgets/
│   │       ├── compass_3d_renderer.dart  # 3D Vector Compass CustomPainter
│   │       ├── floor_level_selector.dart
│   │       └── sensor_status_badge.dart
│   └── features/
│       ├── canvassing/
│       ├── doorway_checkin/
│       ├── map_selection/
│       └── navigation/
├── service_locator.dart                  # Dependency injection registry
└── main.dart                             # Application entrypoint
```

---

## Mathematical Formulations

### 1. Offline Barometric Elevation
$$\Delta z(t) = 44330 \cdot \left(1 - \left(\frac{P(t)}{P_0}\right)^{\frac{1}{5.255}}\right)$$
*   $P_0$: Latched ambient pressure at doorway entrance.
*   $P(t)$: Current reading from phone's hardware barometer.

### 2. Pedestrian Dead Reckoning (PDR)
$$L_k = K \cdot \sqrt[4]{a_{\max} - a_{\min}}$$
$$x_k = x_{k-1} + L_k \cos(\theta_k)$$
$$y_k = y_{k-1} + L_k \sin(\theta_k)$$
*   $K \approx 0.42$ (Weinberg stride model constant).
*   $\theta_k$: Azimuth from rotation vector / magnetometer.

### 3. 3D Compass Vector
$$\vec{V} = \mathbf{P}_{\text{target}} - \mathbf{P}_{\text{user}} = (\Delta x, \Delta y, \Delta z)$$
$$\text{Bearing } \phi = \text{atan2}(\Delta y, \Delta x) - \theta_{\text{heading}}$$
$$\text{Pitch } \alpha = \text{atan2}\left(\Delta z, \sqrt{\Delta x^2 + \Delta y^2}\right)$$

---

## Running the Project

### Requirements
- Android Device running Android 10+ (API 29+) with Barometer, Accelerometer, Gyroscope, and Magnetometer.
- ARCore support recommended for the Canvassing / Surveying module.

### Commands
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run automated tests
flutter test

# 3. Build Android APK
flutter build apk --release
```
