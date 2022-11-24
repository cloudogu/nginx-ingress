#!groovy
@Library(['github.com/cloudogu/dogu-build-lib@v1.6.0', 'github.com/cloudogu/ces-build-lib@1.54.0'])
import com.cloudogu.ces.cesbuildlib.*
import com.cloudogu.ces.dogubuildlib.*
import groovy.json.JsonBuilder

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
            String doguVersion = getDoguVersion(false)
            GString sourceDeploymentYaml = "target/make/k8s/${repositoryName}_${doguVersion}.yaml"

            stage('Set up k3d cluster') {
                k3d.startK3d()
            }

            String imageName
            stage('Build & Push Image') {
                String namespace = getDoguNamespace()
                imageName = k3d.buildAndPushToLocalRegistry("${namespace}/${repositoryName}", doguVersion)
            }

            stage('Setup') {
                k3d.setup("v0.8.0", [
                        dependencies: ["official/postfix"],
                        defaultDogu : ""
                ])
            }

            stage('Deploy Dogu') {
                k3d.installDogu(repositoryName, imageName, sourceDeploymentYaml)
            }

            stage('Wait for Ready Rollout') {
                k3d.waitForDeploymentRollout(repositoryName, 300, 5)
            }

            stage('Test Nginx with PlantUML Deployment') {
                nginxStaticStringYamlDescriptor = DoguResourceFor("nginx-static", "k8s", "1.23.1-2")
                plantumlStringYamlDescriptor = DoguResourceFor("plantuml", "official", "2022.4-1")

                k3d.kubectl("apply -f ${nginxStaticStringYamlDescriptor} -f ${plantumlStringYamlDescriptor}")
                testPlantUmlAccess(k3d)
            }

            stageAutomaticRelease()
        } catch(Exception e) {
            try {
                printCesResourceYamls(k3d)
            } finally {
                throw e
            }
        }
        finally {
            stage('Remove k3d cluster') {
                k3d.deleteK3d()
            }
        }
    }
}

void printCesResourceYamls(K3d k3d) {
    def relevantResources = [
            "persistentvolumeclaim",
            "statefulset",
            "replicaset",
            "deployment",
            "service",
            "secret",
            "pod",
    ]
    def result
    for(def resource : relevantResources) {
        def result1 = k3d.kubectl("get ${resource} --show-kind --ignore-not-found -l app=ces -n ecosystem -o yaml", true)
        def output2 = sh.returnStdOut("echo ${result1}")
        echo "${output2}"
        writeFile(file: "${resource}.yaml", text: result1)
    }
    def result1 = k3d.kubectl("get dogu --show-kind --ignore-not-found -n ecosystem -o yaml", true)
    def output2 = sh.returnStdOut("echo ${result1}")
    echo "${output2}"
    writeFile(file: "dogus.yaml", text: result1)
}

String DoguResourceFor(String doguName, String doguNamespace, String version) {
    def filename = "target/make/k8s/${doguName}.yaml"
    def doguContentYaml = """
apiVersion: k8s.cloudogu.com/v1
kind: Dogu
metadata:
  name: ${doguName}
  labels:
    dogu: ${doguName}
spec:
  name: ${doguNamespace}/${doguName}
  version: ${version}
"""
    writeFile(file: filename, text: doguContentYaml)

    return filename
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
                                make 'k8s-create-temporary-resource'
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
