#!/usr/bin/env python3
"""Configures AndroidManifest.xml and app/build.gradle for 3DCompass."""

import os
import re

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
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
"""

    if "android.permission.HIGH_SAMPLING_RATE_SENSORS" not in content:
        content = content.replace("<application", permissions + "\n    <application")

    if "requestLegacyExternalStorage" not in content:
        content = content.replace("<application", '<application android:requestLegacyExternalStorage="true"')

    if "com.google.ar.core" not in content:
        ar_meta = '\n        <meta-data android:name="com.google.ar.core" android:value="optional" />\n'
        content = content.replace("</activity>", "</activity>" + ar_meta)

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Configured AndroidManifest.xml successfully.")

def configure_build_gradle():
    gradle_path = os.path.join("android", "app", "build.gradle")
    if not os.path.exists(gradle_path):
        print(f"build.gradle not found at {gradle_path}")
        return

    with open(gradle_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Replace compileSdk
    content = re.sub(r'compileSdkVersion\s+[^\n]+', 'compileSdkVersion 34', content)
    content = re.sub(r'compileSdk\s*=\s*[^\n]+', 'compileSdk = 34', content)
    content = re.sub(r'compileSdk\s+flutter\.[^\n]+', 'compileSdk 34', content)

    # Replace minSdk
    content = re.sub(r'minSdkVersion\s+[^\n]+', 'minSdkVersion 24', content)
    content = re.sub(r'minSdk\s*=\s*[^\n]+', 'minSdk = 24', content)
    content = re.sub(r'minSdk\s+flutter\.[^\n]+', 'minSdk = 24', content)

    # Replace targetSdk
    content = re.sub(r'targetSdkVersion\s+[^\n]+', 'targetSdkVersion 34', content)
    content = re.sub(r'targetSdk\s*=\s*[^\n]+', 'targetSdk = 34', content)
    content = re.sub(r'targetSdk\s+flutter\.[^\n]+', 'targetSdk = 34', content)

    with open(gradle_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Configured app/build.gradle successfully.")

if __name__ == "__main__":
    configure_manifest()
    configure_build_gradle()
