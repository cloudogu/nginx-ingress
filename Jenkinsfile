#!groovy

@Library(['github.com/cloudogu/dogu-build-lib@v1.6.0', 'github.com/cloudogu/ces-build-lib@c1cb91cd'])
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
gpg = new Gpg(this, docker)
goVersion = "1.18"

// Configuration of repository
repositoryOwner = "cloudogu"
repositoryName = "nginx-ingress"
project = "github.com/${repositoryOwner}/${repositoryName}"

// Configuration of branches
productionReleaseBranch = "main"

node('docker') {
    timestamps {
        stage('Checkout') {
            checkout scm
            make 'clean'
        }

        stage('Lint') {
            lintDockerfile()
        }

        stage('Shellcheck') {
            shellCheck('./resources/startup.sh ./resources/injectNginxConfig.sh')
        }

        stage('Generate k8s Resources') {
            docker.image("golang:${goVersion}")
                    .mountJenkinsUser()
                    .inside("--volume ${WORKSPACE}:/workdir -w /workdir") {
                        make 'k8s-create-temporary-resource'
                    }
            archiveArtifacts 'target/make/k8s/*.yaml'
        }

        K3d k3d = new K3d(this, "${WORKSPACE}", "${WORKSPACE}/k3d", env.PATH)

        try {
            Makefile makefile = new Makefile(this)
            String doguVersion = makefile.getVersion()
            GString sourceDeploymentYaml = "target/make/k8s/${repositoryName}_${doguVersion}.yaml"

            stage('Set up k3d cluster') {
                k3d.startK3d()
            }

            String imageName
            stage('Build & Push Image') {
                def doguJson = this.readJSON file: 'dogu.json'
                String namespace = doguJson.Name.split("/")[0]
                imageName = k3d.buildAndPushToLocalRegistry("${namespace}/${repositoryName}", doguVersion)
            }

            stage('Setup') {
                k3d.setup("v0.6.0", [
                        dependencies: ["official/postfix", "official/plantuml"],
                        defaultDogu : "plantuml"
                ])
            }

            stage('Deploy Dogu') {
                k3d.installDogu(repositoryName, imageName, sourceDeploymentYaml)
            }

            stage('Wait for Ready Rollout') {
                k3d.waitForDeploymentRollout(repositoryName, 300, 5)
            }

            stage('Test Nginx with PlantUML Deployment') {
                testPlantUmlAccess(k3d)
            }

            stageAutomaticRelease()
        } finally {
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

    if (!plantUml.contains("<title>PlantUMLServer</title>")) {
        sh "echo PlantUML does not seem to be available. Fail pipeline..."
        sh "exit 1"
    }
}

void stageAutomaticRelease() {
    if (gitflow.isReleaseBranch()) {
        String releaseVersion = git.getSimpleBranchName()
        String dockerReleaseVersion = releaseVersion.split("v")[1]
        def doguJson = this.readJSON file: 'dogu.json'
        String namespace = doguJson.Name.split("/")[0]
        String credentials = 'cesmarvin-setup'
        def dockerImage

        stage('Build & Push Image') {
            dockerImage = docker.build("${namespace}/${repositoryName}:${dockerReleaseVersion}")
            docker.withRegistry('https://registry.cloudogu.com/', credentials) {
                dockerImage.push("${dockerReleaseVersion}")
            }
        }

        stage('Push dogu.json') {
            HttpClient httpClient = new HttpClient(this, credentials)
            result = httpClient.put("https://dogu.cloudogu.com/api/v2/${doguJson.Name}", "application/json", doguJson)
            status = result["httpCode"]
            body = result["body"]

            if (status >= 400) {
                echo "Error pushing dogu.json"
                echo "${body}"
            }
        }

        stage('Finish Release') {
            gitflow.finishRelease(releaseVersion, productionReleaseBranch)
        }

        stage('Sign after Release') {
            gpg.createSignature()
        }

        stage('Regenerate resources for release') {
            new Docker(this)
                    .image("golang:${goVersion}")
                    .mountJenkinsUser()
                    .inside("--volume ${WORKSPACE}:/go/src/${project} -w /go/src/${project}")
                            {
                                make 'k8s-create-temporary-resource'
                            }
        }

        stage('Add Github-Release') {
            Makefile makefile = new Makefile(this)
            String doguVersion = makefile.getVersion()
            GString doguYaml = "target/make/k8s/${repositoryName}_${doguVersion}.yaml"
            releaseId = github.createReleaseWithChangelog(releaseVersion, changelog, productionReleaseBranch)
            github.addReleaseAsset("${releaseId}", "${doguYaml}")
            github.addReleaseAsset("${releaseId}", "${doguYaml}.sha256sum")
            github.addReleaseAsset("${releaseId}", "${doguYaml}.sha256sum.asc")
        }
    }
}

void make(String makeArgs) {
    sh "make ${makeArgs}"
}
