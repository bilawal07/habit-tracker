# Keep Flutter & plugin classes safe under R8 shrinking
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep flutter_local_notifications receivers and Gson models
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Optional Play Core deferred-component classes referenced by Flutter embedding
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
