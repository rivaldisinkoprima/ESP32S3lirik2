# Build Guide - Flutter App

## Persiapan Environment

### 1. Install Flutter SDK

```bash
# Download Flutter SDK from https://docs.flutter.dev/get-started/install
# Extract ke folder yang diinginkan, contoh: C:\flutter

# Add ke PATH
setx PATH "%PATH%;C:\flutter\bin"
```

### 2. Install Android SDK

```bash
# Install Android Studio atau command line tools
# Download dari: https://developer.android.com/studio

# Set environment variable
setx ANDROID_HOME "C:\Android"
setx ANDROID_SDK_ROOT "C:\Android"
```

### 3. Verifikasi Installasi

```bash
flutter doctor
```

Expected output:
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter - is installed
[✓] Android toolchain - is installed
[✓] Chrome - is available
[✓] Windows Desktop - is enabled
[✓] Visual Studio - is installed
```

---

## Build APK

### Debug Build (Development)

```bash
cd flutter
flutter pub get
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release Build (Production)

```bash
cd flutter
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Build Options

### Specific Build Target

```bash
# Build untuk arsitektur tertentu
flutter build apk --target-platform android-arm64
flutter build apk --target-platform android-arm
flutter build apk --target-platform android-x64
```

### Build dengan Versi Custom

```bash
# Ubah versi di pubspec.yaml terlebih dahulu
flutter build apk --build-name=1.0.0 --build-number=1
```

### Split APKs (untuk Play Store)

```bash
flutter build apk --split-per-abi
```

Output:
- `app-armeabi-v7a.apk`
- `app-arm64-v8a.apk`
- `app-x86_64.apk`

---

## Troubleshooting Build

### Error: NDK not found / corrupt

```bash
# Hapus folder NDK corrupt
Remove-Item -Path "C:\Android\ndk\*" -Recurse -Force

# Build ulang tanpa NDK version specification
flutter clean
flutter build apk
```

### Error: SDK version mismatch

```bash
# Update SDK dan build-tools
sdkmanager "platforms;android-34" "build-tools;34.0.0"
```

### Error: Java version

```bash
# Install Java 17
# Download dari https://adoptium.net/

setx JAVA_HOME "C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot"
```

### Error: Gradle permission (Linux/Mac)

```bash
chmod +x android/gradlew
./android/gradlew assembleRelease
```

---

## Install ke Device

### Via USB Debugging

```bash
# Enable Developer Options & USB Debugging di device
# Connect device via USB

flutter install
```

### Via ADB

```bash
# Copy APK ke device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Via WiFi (Tanpa Kabel)

```bash
# Connect device via USB dulu, lalu:
adb tcpip 5555
adb connect 192.168.1.100:5555
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Build Commands Reference

| Command | Deskripsi |
|---------|-----------|
| `flutter pub get` | Install dependencies |
| `flutter pub upgrade` | Update dependencies ke versi terbaru |
| `flutter clean` | Hapus folder build |
| `flutter build apk` | Build APK (debug) |
| `flutter build apk --debug` | Build APK debug |
| `flutter build apk --release` | Build APK release |
| `flutter build apk --split-per-abi` | Build APK per arsitektur |
| `flutter build appbundle` | Build App Bundle (Play Store) |
| `flutter build ios` | Build iOS (hanya di Mac) |
| `flutter build web` | Build Web |
| `flutter analyze` | Analyze code tanpa build |
| `flutter test` | Run unit tests |

---

## File APK Setelah Build

```
flutter/
├── build/
│   └── app/
│       └── outputs/
│           └── flutter-apk/
│               ├── app-debug.apk
│               └── app-release.apk
```

---

## Continuous Integration (CI)

### GitHub Actions Example

```yaml
name: Build APK

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          
      - name: Get dependencies
        run: flutter pub get
        
      - name: Build APK
        run: flutter build apk --release
        
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: apk
          path: build/app/outputs/flutter-apk/app-release.apk
```
