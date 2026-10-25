# Picked up automatically by the Flutter Gradle plugin for release builds (R8).

# Urovo URFIDLibrary (RFID Development Documentation v2.25, Appendix 5).
# The native serial drivers look up Java fields by name (e.g. SerialPort.mFd) and the SDK uses reflection.
-keep class com.rfid.** { *; }
-keep class com.rfiddevice.** { *; }
-keep class com.android.hw.** { *; }
-keep class com.ubx.** { *; }
-keep class com.iflytek.** { *; }
-keep class com.lib.** { *; }
-keep class android.device.** { *; }
-keep class android.os.** { *; }

# Classes provided only by the Urovo ROM, and the Nordic DFU library (BLE sleds only, not bundled).
-dontwarn android.device.**
-dontwarn android.os.IKeyEventCallback
-dontwarn android.content.pm.IPackageDeleteObserver
-dontwarn android.content.pm.IPackageInstallObserver
-dontwarn no.nordicsemi.android.dfu.**
