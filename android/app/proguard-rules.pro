# Disable warnings for missing ML Kit optional script recognition classes.
# We only use latin, so chinese, korean, japanese, and devanagari are not imported,
# but the ML Kit core library tries to reference them via reflection or builder patterns.

-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
