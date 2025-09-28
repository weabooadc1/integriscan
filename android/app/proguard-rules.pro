# TensorFlow Lite - Keep all classes and nested classes
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