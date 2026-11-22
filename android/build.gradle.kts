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

subprojects {
    val configureAndroid: (Project) -> Unit = { p ->
        val android = p.extensions.findByName("android")
        if (android != null) {
            val methods = android.javaClass.methods.filter {
                it.name in listOf("setCompileSdk", "setCompileSdkVersion", "compileSdkVersion") && it.parameterCount == 1
            }
            for (m in methods) {
                try {
                    val paramType = m.parameterTypes[0]
                    if (paramType == java.lang.Integer::class.java || paramType == java.lang.Integer.TYPE) {
                        m.invoke(android, 36)
                    } else if (paramType == java.lang.String::class.java) {
                        m.invoke(android, "android-36")
                    }
                } catch (_: Throwable) {}
            }
        }
    }

    if (state.executed) {
        configureAndroid(this)
    } else {
        afterEvaluate { configureAndroid(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
