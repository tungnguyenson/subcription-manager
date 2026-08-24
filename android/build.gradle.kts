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
}

// flutter_secure_storage 11.0.0 dat cung compileSdk = 37. SDK manager chi phat
// hanh goi ten "android-37.0" con AGP di tim "android-37"; ban than AGP 9.1.0
// cung chi khuyen nghi toi 36. Ma Java cua plugin khong dung API nao tren 30
// (VERSION_CODES.R la cao nhat) nen bien dich voi 36 khong mat gi.
//
// Khoi nay phai nam TREN khoi evaluationDependsOn(":app") ben duoi. Dat sau thi
// :app da evaluate xong va afterEvaluate nem "project is already evaluated".
// Cung phai la afterEvaluate chu khong phai plugins.withId, vi build.gradle cua
// plugin chay sau khi plugin duoc apply va se ghi de lai gia tri.
subprojects {
    project.afterEvaluate {
        val ext = extensions.findByName("android")
        if (ext is com.android.build.gradle.LibraryExtension) {
            val current = ext.compileSdk
            if (current != null && current > 36) {
                ext.compileSdk = 36
                // Ha ca minCompileSdk trong metadata AAR, khong thi :app do o
                // checkDebugAarMetadata du thu vien da bien dich xong voi 36.
                ext.defaultConfig.aarMetadata.minCompileSdk = 36
                logger.lifecycle("[subdock] ${project.name}: compileSdk $current -> 36")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
