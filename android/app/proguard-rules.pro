# MediaPipe / flutter_gemma — keep inference engine classes
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }

# tflite_flutter — R8 release builds fail with "Missing class
# org.tensorflow.lite.gpu.GpuDelegateFactory$Options" without these
# (tflite_flutter issue #278).
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# MediaPipe profiler protos + variantes de langue ML Kit text recognition
# (chinois/devanagari/japonais/coréen) non embarquées — on n'utilise que le
# latin. Références mortes, sûres à ignorer (générées par R8 missing_rules).
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
