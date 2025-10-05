# ===== Google Play Core - Suppress warnings for unused classes =====
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ===== VLC Player - CRITICAL for Release Builds =====
# Keep all VLC native library classes
-keep class org.videolan.libvlc.** { *; }
-dontwarn org.videolan.libvlc.**
-keep class org.videolan.medialibrary.** { *; }
-dontwarn org.videolan.medialibrary.**

# Flutter VLC Player Plugin
-keep class software.solid.fluttervlcplayer.** { *; }
-dontwarn software.solid.fluttervlcplayer.**

# Keep VLC JNI methods
-keepclasseswithmembers class * {
    native <methods>;
}

# ===== Flutter Core =====
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ===== TensorFlow Lite - Keep all classes and nested classes =====
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.**$* { *; }

# TensorFlow Lite GPU Delegate - More specific rules
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.gpu.**$* { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate$* { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$* { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
-keep class org.tensorflow.lite.gpu.CompatibilityList { *; }

# Generated missing rules from Android Gradle plugin
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# TensorFlow Lite NNAPI and other delegates
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.nnapi.**$* { *; }
-keep class org.tensorflow.lite.delegates.** { *; }
-keep class org.tensorflow.lite.delegates.**$* { *; }

# Keep TensorFlow Lite model loading
-keep class org.tensorflow.lite.Interpreter { *; }
-keep class org.tensorflow.lite.Interpreter$* { *; }
-keep class org.tensorflow.lite.InterpreterApi { *; }
-keep class org.tensorflow.lite.InterpreterApi$* { *; }
-keep class org.tensorflow.lite.Tensor { *; }
-keep class org.tensorflow.lite.Tensor$* { *; }

# Keep DataType enum and related classes
-keep class org.tensorflow.lite.DataType { *; }
-keep enum org.tensorflow.lite.DataType { *; }

# Prevent obfuscation of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all constructors for TensorFlow Lite classes
-keepclassmembers class org.tensorflow.lite.** {
    <init>(...);
}