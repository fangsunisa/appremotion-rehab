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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureAction: Project.() -> Unit = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setter = android.javaClass.getMethod("setCompileSdk", Int::class.java)
                setter.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    val setter = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setter.invoke(android, 36)
                } catch (ignored: Exception) {}
            }
        }
    }
    if (state.executed) {
        configureAction()
    } else {
        afterEvaluate(configureAction)
    }
}