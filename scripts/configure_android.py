#!/usr/bin/env python3
"""Configures AndroidManifest.xml and app/build.gradle[.kts] for 3DCompass."""

import os
import re
import shutil

def configure_manifest():
    manifest_path = os.path.join("android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.exists(manifest_path):
        print(f"Manifest not found at {manifest_path}")
        return

    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()

    permissions = """
    <!-- High-rate sensor telemetry for PDR and AHRS -->
    <uses-permission android:name="android.permission.HIGH_SAMPLING_RATE_SENSORS" />
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
    <uses-permission android:name="android.permission.BODY_SENSORS" />

    <!-- Barometer hardware feature flag -->
    <uses-feature android:name="android.hardware.sensor.barometer" android:required="false" />
    <uses-feature android:name="android.hardware.sensor.accelerometer" android:required="true" />
    <uses-feature android:name="android.hardware.sensor.gyroscope" android:required="true" />
    <uses-feature android:name="android.hardware.sensor.compass" android:required="true" />

    <!-- Faint GNSS reception for doorway anchoring -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- Camera & Google ARCore -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
"""

    if "android.permission.HIGH_SAMPLING_RATE_SENSORS" not in content:
        content = content.replace("<application", permissions + "\n    <application")

    if "requestLegacyExternalStorage" not in content:
        content = content.replace("<application", '<application android:requestLegacyExternalStorage="true"')

    if "hasFragileUserData" not in content:
        content = content.replace("<application", '<application android:hasFragileUserData="true"')

    if "com.google.ar.core" not in content:
        ar_meta = '\n        <meta-data android:name="com.google.ar.core" android:value="optional" />\n'
        content = content.replace("</activity>", "</activity>" + ar_meta)

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Configured AndroidManifest.xml successfully.")

def configure_build_gradle():
    # 1. Copy persistent release keystore into android/app/ if available
    src_keystore = os.path.join("keystore", "release.keystore")
    target_keystore = os.path.join("android", "app", "release.keystore")
    if os.path.exists(src_keystore):
        os.makedirs(os.path.dirname(target_keystore), exist_ok=True)
        shutil.copy2(src_keystore, target_keystore)
        print(f"Copied {src_keystore} to {target_keystore}")

    candidates = [
        os.path.join("android", "app", "build.gradle"),
        os.path.join("android", "app", "build.gradle.kts"),
    ]

    found = False
    for gradle_path in candidates:
        if not os.path.exists(gradle_path):
            continue

        found = True
        with open(gradle_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Replace compileSdk (minimum 36 required by geolocator_android and jni_flutter)
        content = re.sub(r'compileSdkVersion\s+[^\n]+', 'compileSdkVersion 36', content)
        content = re.sub(r'compileSdk\s*=\s*[^\n]+', 'compileSdk = 36', content)
        content = re.sub(r'compileSdk\s+flutter\.[^\n]+', 'compileSdk 36', content)

        # Replace minSdk
        content = re.sub(r'minSdkVersion\s+[^\n]+', 'minSdkVersion 24', content)
        content = re.sub(r'minSdk\s*=\s*[^\n]+', 'minSdk = 24', content)
        content = re.sub(r'minSdk\s+flutter\.[^\n]+', 'minSdk = 24', content)

        # Replace targetSdk
        content = re.sub(r'targetSdkVersion\s+[^\n]+', 'targetSdkVersion 34', content)
        content = re.sub(r'targetSdk\s*=\s*[^\n]+', 'targetSdk = 34', content)
        content = re.sub(r'targetSdk\s+flutter\.[^\n]+', 'targetSdk = 34', content)

        # Configure signingConfigs.release
        if gradle_path.endswith('.kts'):
            if 'signingConfigs {' not in content:
                signing_block = """
    signingConfigs {
        create("release") {
            storeFile = file("release.keystore")
            storePassword = "compass3d_secret"
            keyAlias = "compass3d"
            keyPassword = "compass3d_secret"
        }
    }
"""
                content = content.replace("android {", "android {" + signing_block)
            content = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("release")', content)
        else:
            if 'signingConfigs {' not in content:
                signing_block = """
    signingConfigs {
        release {
            storeFile file("release.keystore")
            storePassword "compass3d_secret"
            keyAlias "compass3d"
            keyPassword "compass3d_secret"
        }
    }
"""
                content = content.replace("android {", "android {" + signing_block)
            content = re.sub(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.release', content)

        with open(gradle_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Configured {gradle_path} successfully.")

    if not found:
        print("ERROR: Neither build.gradle nor build.gradle.kts found!")

if __name__ == "__main__":
    configure_manifest()
    configure_build_gradle()
