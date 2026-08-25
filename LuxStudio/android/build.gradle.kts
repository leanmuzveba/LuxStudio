allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Some plugins (flutter_secure_storage, permission_handler_android) request
    // `flutter.compileSdkVersion`, which currently resolves to a preview API 37
    // that the Android SDK downloader installs under a mismatched folder name
    // (`android-37.0` instead of `android-37`), breaking the build. Pin every
    // module to the confirmed-working, fully-installed API 36 instead — this
    // app doesn't need anything from 37. Registered here, before
    // `evaluationDependsOn(":app")` below forces early evaluation of :app,
    // so the hook is queued in time (afterEvaluate throws if added once a
    // project has already finished evaluating).
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
