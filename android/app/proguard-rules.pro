# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Keep encrypt package classes from obfuscation
-keep class org.bouncycastle.** { *; }
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }
-keep class encrypt.** { *; }
-keep class dart.core.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class com.example.oro_ticket_app.** { *; }

# Keep classes that use reflection
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault

-keepclassmembers class * {
    @org.bouncycastle.* <fields>;
    @org.bouncycastle.* <methods>;
}

# Keep encrypt package specific classes
-dontwarn org.bouncycastle.**
-dontwarn javax.crypto.**
-dontwarn encrypt.**
-dontwarn dart.**

# Keep all classes in the encrypt package
-keep class encrypt.** { *; }
-keep class org.bouncycastle.crypto.** { *; }
-keep class org.bouncycastle.jcajce.** { *; }

# Suppress warnings for Play Core classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task