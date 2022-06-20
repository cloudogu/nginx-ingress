#!groovy

@Library(['github.com/cloudogu/dogu-build-lib@v1.6.0', 'github.com/cloudogu/ces-build-lib@638292d0fd93ad6532b72195f9aa3733098e12a3'])
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
developmentBranch = "develop"
currentBranch = "${env.BRANCH_NAME}"

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
                k3d.setup("v0.6.0", 300, 5)
            }

            stage('Deploy Dogu') {
                k3d.installDogu(repositoryName, imageName, sourceDeploymentYaml)
            }

            stage('Wait for Ready Rollout') {
                k3d.waitForDeploymentRollout(repositoryName, 300, 5)
            }

            stage('Test') {
                // TODO
            }

            stageAutomaticRelease()
        } finally {
            stage('Remove k3d cluster') {
                k3d.deleteK3d()
            }
        }
    }
}

void gitWithCredentials(String command) {
    withCredentials([usernamePassword(credentialsId: 'cesmarvin', usernameVariable: 'GIT_AUTH_USR', passwordVariable: 'GIT_AUTH_PSW')]) {
        sh(
                script: "git -c credential.helper=\"!f() { echo username='\$GIT_AUTH_USR'; echo password='\$GIT_AUTH_PSW'; }; f\" " + command,
                returnStdout: true
        )
    }
}

void stageAutomaticRelease() {
    if (gitflow.isReleaseBranch()) {
        String releaseVersion = git.getSimpleBranchName()
        String dockerReleaseVersion = releaseVersion.split("v")[1]

        stage('Build & Push Image') {
            def doguJson = this.readJSON file: 'dogu.json'
            String namespace = doguJson.Name.split("/")[0]
            def dockerImage = docker.build("${namespace}/${repositoryName}:${dockerReleaseVersion}")
            docker.withRegistry('https://registry.cloudogu.com/', 'cesmarvin-setup') {
                dockerImage.push("${dockerReleaseVersion}")
            }
            // TODO Push dogu.json
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
