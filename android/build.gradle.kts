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
    project.layout.buildDirectory.set(File(absoluteBuildDir, project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
