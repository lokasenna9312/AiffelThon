allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins {
    id("com.android.application") apply false // 또는 id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false // 또는 id("kotlin-android") apply false
    id("com.google.gms.google-services") apply false // <-- 이 라인을 추가하거나 확인합니다. 버전은 최신으로 유지합니다.
}