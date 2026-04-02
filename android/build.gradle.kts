buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Compute the build directory as a true absolute Java File so Gradle never
// attempts a relative-path calculation across different Windows drive letters
// (e.g. E:\project vs C:\pub-cache), which would throw "different roots".
val absoluteBuildDir: File = rootProject.rootDir.parentFile.resolve("build").canonicalFile
rootProject.layout.buildDirectory.set(absoluteBuildDir)

subprojects {
    // Check if the subproject is on the same drive as the root project to avoid cross-drive errors.
    // If on a different drive (like E: pub cache vs C: project), use a local build dir for the plugin.
    val rootDrive = rootProject.rootDir.path.substring(0, 3)
    val projectDrive = project.projectDir.path.substring(0, 3)
    
    if (rootDrive.equals(projectDrive, ignoreCase = true)) {
        project.layout.buildDirectory.set(File(absoluteBuildDir, project.name))
    } else {
        project.layout.buildDirectory.set(File(project.projectDir, "build"))
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
