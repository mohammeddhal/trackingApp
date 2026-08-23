allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = rootProject.layout.buildDirectory.dir(project.name).get()
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        project.extensions.findByName("android")?.apply {
            try {
                val method = this.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                method.invoke(this, 36)
            } catch (e: Exception) {}
            try {
                val method = this.javaClass.getMethod("setCompileSdk", Int::class.java)
                method.invoke(this, 36)
            } catch (e: Exception) {}
        }
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

