#!groovy
@Library(['github.com/cloudogu/dogu-build-lib@v3.1.0', 'github.com/cloudogu/ces-build-lib@4.2.0'])
import com.cloudogu.ces.cesbuildlib.*
import com.cloudogu.ces.dogubuildlib.*

// Creating necessary git objects
git = new Git(this, "cesmarvin")
git.committerName = 'cesmarvin'
git.committerEmail = 'cesmarvin@cloudogu.com'
gitflow = new GitFlow(this, git)
github = new GitHub(this, git)
changelog = new Changelog(this)
Docker docker = new Docker(this)
goVersion = "1.24.1"

// Configuration of repository
repositoryOwner = "cloudogu"
repositoryName = "nginx-ingress"
project = "github.com/${repositoryOwner}/${repositoryName}"

// Configuration of branches
productionReleaseBranch = "main"

node('docker') {
    timestamps {
        properties([
                // Keep only the last x builds to preserve space
                buildDiscarder(logRotator(numToKeepStr: '10')),
                // Don't run concurrent builds for a branch, because they use the same workspace directory
                disableConcurrentBuilds(),
                parameters([
                        choice(name: 'TrivySeverityLevels', choices: [TrivySeverityLevel.CRITICAL, TrivySeverityLevel.HIGH_AND_ABOVE, TrivySeverityLevel.MEDIUM_AND_ABOVE, TrivySeverityLevel.ALL], description: 'The levels to scan with trivy'),
                        choice(name: 'TrivyStrategy', choices: [TrivyScanStrategy.UNSTABLE, TrivyScanStrategy.FAIL, TrivyScanStrategy.IGNORE], description: 'Define whether the build should be unstable, fail or whether the error should be ignored if any vulnerability was found.'),
                ])
        ])

        stage('Checkout') {
            checkout scm
            make 'clean'
        }

        stage('Lint') {
            Dockerfile dockerfile = new Dockerfile(this)
            dockerfile.lintWithConfig()
        }

        stage('Check Markdown Links') {
            Markdown markdown = new Markdown(this)
            markdown.check()
        }

        stage('Shellcheck') {
            shellCheck('./resources/startup.sh ./resources/injectNginxConfig.sh')
        }

        stage('Generate k8s Resources') {
            docker.image("golang:${goVersion}")
                    .mountJenkinsUser()
                    .inside("--volume ${WORKSPACE}:/workdir -w /workdir") {
                        make 'create-dogu-resource'
                    }
            archiveArtifacts 'target/k8s/*.yaml'
        }

        K3d k3d = new K3d(this, "${WORKSPACE}", "${WORKSPACE}/k3d", env.PATH)

        try {
            String doguVersion = getDoguVersion(false)
            GString sourceDeploymentYaml = "target/k8s/${repositoryName}.yaml"

            stage('Set up k3d cluster') {
                k3d.startK3d()
            }

            String imageName
            stage('Build & Push Image') {
                String namespace = getDoguNamespace()
                imageName = k3d.buildAndPushToLocalRegistry("${namespace}/${repositoryName}", doguVersion)
            }

            stage('Setup') {
                k3d.setup("3.4.1", [additionalDependencies: ["official/postgresql"], defaultDogu : ""])
            }

            stage('Deploy Dogu') {
                k3d.installDogu(repositoryName, imageName, sourceDeploymentYaml)
            }

            stage('Wait for Ready Rollout') {
                k3d.waitForDeploymentRollout(repositoryName, 300, 5)
            }

            stage('Test Nginx with PlantUML Deployment') {
                k3d.applyDoguResource("plantuml", "official", "2025.0-2")
                testPlantUmlAccess(k3d)
            }

            stage('Trivy scan') {
                Trivy trivy = new Trivy(this)
                String namespace = getDoguNamespace()
                // We do not build the dogu in the single node ecosystem, therefore we just use scanImage here with the build from the k3s step.
                trivy.scanImage("${namespace}/${repositoryName}:${doguVersion}", params.TrivySeverityLevels, params.TrivyStrategy)
                trivy.saveFormattedTrivyReport(TrivyScanFormat.TABLE)
                trivy.saveFormattedTrivyReport(TrivyScanFormat.JSON)
                trivy.saveFormattedTrivyReport(TrivyScanFormat.HTML)
            }

            stageAutomaticRelease()
        }
        catch(Exception e) {
            k3d.collectAndArchiveLogs()
            throw e as java.lang.Throwable
        }
        finally {
            stage('Remove k3d cluster') {
                k3d.deleteK3d()
            }
        }
    }
}

/**
 * Creates a simple plantuml deployment and checks whether the dogu is accessible via the nginx.
 */
void testPlantUmlAccess(K3d k3d) {
    k3d.waitForDeploymentRollout("plantuml", 300, 5)

    String port = sh(script: 'echo -n $(python3 -c \'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()\');', returnStdout: true)

    // the process is automatically terminated when canceling/terminating the build
    k3d.kubectl("port-forward service/nginx-ingress ${port}:443 &")

    sh "sleep 5"

    String plantUml = sh(
            script: "curl -L --insecure https://127.0.0.1:${port}/plantuml",
            returnStdout: true
    )

    if (!plantUml.contains("<title>PlantUML Server</title>")) {
        sh "echo PlantUML does not seem to be available. Fail pipeline..."
        sh "exit 1"
    }
}

void stageAutomaticRelease() {
    if (gitflow.isReleaseBranch()) {
        String releaseVersion = getDoguVersion(true)
        String dockerReleaseVersion = getDoguVersion(false)
        String namespace = getDoguNamespace()
        String credentials = 'cesmarvin-setup'
        def dockerImage

        stage('Build & Push Image') {
            dockerImage = docker.build("${namespace}/${repositoryName}:${dockerReleaseVersion}")
            docker.withRegistry('https://registry.cloudogu.com/', credentials) {
                dockerImage.push("${dockerReleaseVersion}")
            }
        }

        stage('Push dogu.json') {
            String doguJson = sh(script: "cat dogu.json", returnStdout: true)
            HttpClient httpClient = new HttpClient(this, credentials)
            result = httpClient.put("https://dogu.cloudogu.com/api/v2/dogus/${namespace}/${repositoryName}", "application/json", doguJson)
            status = result["httpCode"]
            body = result["body"]

            if ((status as Integer) >= 400) {
                echo "Error pushing dogu.json"
                echo "${body}"
                sh "exit 1"
            }
        }

        stage('Finish Release') {
            gitflow.finishRelease(releaseVersion, productionReleaseBranch)
        }

        stage('Regenerate resources for release') {
            new Docker(this)
                    .image("golang:${goVersion}")
                    .mountJenkinsUser()
                    .inside("--volume ${WORKSPACE}:/go/src/${project} -w /go/src/${project}")
                            {
                                make 'create-dogu-resource'
                            }
        }

        stage('Add Github-Release') {
            String doguVersion = getDoguVersion(false)
            GString doguYaml = "target/make/k8s/${repositoryName}_${doguVersion}.yaml"
            releaseId = github.createReleaseWithChangelog(releaseVersion, changelog, productionReleaseBranch)
            github.addReleaseAsset("${releaseId}", "${doguYaml}")
        }
    }
}

String getDoguVersion(boolean withVersionPrefix) {
    def doguJson = this.readJSON file: 'dogu.json'
    String version = doguJson.Version

    if (withVersionPrefix) {
        return "v" + version
    } else {
        return version
    }
}

String getDoguNamespace() {
    def doguJson = this.readJSON file: 'dogu.json'
    return doguJson.Name.split("/")[0]
}

void make(String makeArgs) {
    sh "make ${makeArgs}"
}
