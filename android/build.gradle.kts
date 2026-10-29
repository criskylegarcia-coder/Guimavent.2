import org.gradle.authentication.http.BasicAuthentication

allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox Android SDK is not on Maven Central/Google's repo — it's
        // pulled from Mapbox's own repo, which requires a SEPARATE secret
        // token (Downloads:Read scope, NOT the public pk.* access token
        // used at runtime) as the password below. This must be set in
        // ~/.gradle/gradle.properties (the Gradle user home, outside this
        // project entirely) as MAPBOX_DOWNLOADS_TOKEN=<your secret token>
        // — never in this project's own gradle.properties or any committed
        // file. Generate one at https://account.mapbox.com/access-tokens/.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = (project.findProperty("MAPBOX_DOWNLOADS_TOKEN") as String?) ?: ""
            }
        }
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
