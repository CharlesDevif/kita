# MediaPipe / flutter_gemma — keep inference engine classes
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }

# tflite_flutter — R8 release builds fail with "Missing class
# org.tensorflow.lite.gpu.GpuDelegateFactory$Options" without these
# (tflite_flutter issue #278).
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
