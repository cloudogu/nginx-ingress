#!groovy

@Library(['github.com/cloudogu/dogu-build-lib@v1.6.0', 'github.com/cloudogu/ces-build-lib@1.53.0'])
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
            docker.image('mikefarah/yq:4.22.1')
                    .mountJenkinsUser()
                    .inside("--volume ${WORKSPACE}:/workdir -w /workdir") {
                        make 'clean'
                    }
        }

        stage('Lint') {
            lintDockerfile()
        }

        stage('Shellcheck') {
            shellCheck('./resources/startup.sh ./resources/injectNginxConfig.sh')
        }

        stage('Generate k8s Resources') {
            docker.image('mikefarah/yq:4.22.1')
                    .mountJenkinsUser()
                    .inside("--volume ${WORKSPACE}:/workdir -w /workdir") {
                        make 'k8s-create-temporary-resource'
                    }
            archiveArtifacts 'target/make/k8s/*.yaml'
        }

        stage("Lint k8s Resources") {
            stageLintK8SResources()
        }

//        stage('SonarQube') {
//            stageStaticAnalysisSonarQube()
//        }

        K3d k3d = new K3d(this, "${WORKSPACE}/k3d", env.PATH)

        try {
            Makefile makefile = new Makefile(this)
            String doguVersion = makefile.getVersion()

            stage('Set up k3d cluster') {
                k3d.startK3d()
            }

            def imageName
            stage('Build & Push Image') {
                imageName = k3d.buildAndPushToLocalRegistry("k8s/${repositoryName}", doguVersion)
            }

            GString sourceDeploymentYaml = "target/${repositoryName}.yaml"

            stage('Setup') {
                // Secrets
                // TODO Pick right secrets
                withCredentials([usernamePassword(credentialsId: 'dogu.cloudogu.com', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    k3d.kubectl('generic k8s-dogu-operator-dogu-registry --from-literal=username="\$USER" --from-literal=password="\$PASS" --from-literal=endpoint="https://dogu.cloudogu.com/api/v2/dogus"')
                }

                withCredentials([usernamePassword(credentialsId: 'registry.cloudogu.com', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    k3d.kubectl('create secret docker-registry k8s-dogu-operator-docker-registry --docker-server=registry.cloudogu.com --docker-username="\$USER" --docker-email="test@test.de" --docker-password="\$PASS"')
                }

                // Config
                writeSetupConfig()
                k3d.kubectl('apply -f k8s-ces-setup-config.yaml')

                sleep(time: 300, unit: "SECONDS")

                // No yaml released yet
                // setupYaml = sh "curl -s https://api.github.com/repos/cloudogu/k8s-ces-setup/releases/latest | jq '.assets[] | select(.name|match(\"k8s-ces-setup_.*.yaml\")) | .browser_download_url'"
                // k3d.kubectl('apply -f \${setupYaml}')
                // Use this for test
                writeSetupYaml()
                k3d.kubectl('apply -f setup.yaml')

                sleep(time: 5, unit: "SECONDS")
                k3d.kubectl("wait --for=condition=ready pod -l app.kubernetes.io/name: k8s-ces-setup --timeout=300s")

                writeSetupJson()
                k3d.kubectl('create configmap k8s-ces-setup-json --from-file=setup.json')

                k3d.kubectl("wait --for=condition=ready pod -l statefulset.kubernetes.io/pod-name=etcd-0 --timeout=300s")
            }

            stage('Deploy Dogu') {
                docker.image('mikefarah/yq:4.22.1')
                        .mountJenkinsUser()
                        .inside("--volume ${WORKSPACE}:/workdir -w /workdir") {
                            make('install-dogu-descriptor')
                        }

                k3d.kubectl("apply -f ${sourceDeploymentYaml}")
            }

            stage('Wait for Ready Rollout') {
                sleep(time: 5, unit: "SECONDS")
                k3d.kubectl("--namespace default wait --for=condition=Ready pods --all")
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

void stageLintK8SResources() {
    String kubevalImage = "cytopia/kubeval:0.13"
    Makefile makefile = new Makefile(this)
    String controllerVersion = makefile.getVersion()

    docker
            .image(kubevalImage)
            .inside("-v ${WORKSPACE}/target:/data -t --entrypoint=")
                    {
                        sh "kubeval /data/${repositoryName}_${controllerVersion}.yaml --ignore-missing-schemas"
                    }
}

//void stageStaticAnalysisReviewDog() {
//    def commitSha = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
//
//    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'sonarqube-gh', usernameVariable: 'USERNAME', passwordVariable: 'REVIEWDOG_GITHUB_API_TOKEN']]) {
//        withEnv(["CI_PULL_REQUEST=${env.CHANGE_ID}", "CI_COMMIT=${commitSha}", "CI_REPO_OWNER=${repositoryOwner}", "CI_REPO_NAME=${repositoryName}"]) {
//            make 'static-analysis-ci'
//        }
//    }
//}
//
//void stageStaticAnalysisSonarQube() {
//    def scannerHome = tool name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
//    withSonarQubeEnv {
//        sh "git config 'remote.origin.fetch' '+refs/heads/*:refs/remotes/origin/*'"
//        gitWithCredentials("fetch --all")
//
//        if (currentBranch == productionReleaseBranch) {
//            echo "This branch has been detected as the production branch."
//            sh "${scannerHome}/bin/sonar-scanner -Dsonar.branch.name=${env.BRANCH_NAME}"
//        } else if (currentBranch == developmentBranch) {
//            echo "This branch has been detected as the development branch."
//            sh "${scannerHome}/bin/sonar-scanner -Dsonar.branch.name=${env.BRANCH_NAME}"
//        } else if (env.CHANGE_TARGET) {
//            echo "This branch has been detected as a pull request."
//            sh "${scannerHome}/bin/sonar-scanner -Dsonar.pullrequest.key=${env.CHANGE_ID} -Dsonar.pullrequest.branch=${env.CHANGE_BRANCH} -Dsonar.pullrequest.base=${developmentBranch}"
//        } else if (currentBranch.startsWith("feature/")) {
//            echo "This branch has been detected as a feature branch."
//            sh "${scannerHome}/bin/sonar-scanner -Dsonar.branch.name=${env.BRANCH_NAME}"
//        } else {
//            echo "This branch has been detected as a miscellaneous branch."
//            sh "${scannerHome}/bin/sonar-scanner -Dsonar.branch.name=${env.BRANCH_NAME} "
//        }
//    }
//    timeout(time: 2, unit: 'MINUTES') { // Needed when there is no webhook for example
//        def qGate = waitForQualityGate()
//        if (qGate.status != 'OK') {
//            unstable("Pipeline unstable due to SonarQube quality gate failure")
//        }
//    }
//}

void stageAutomaticRelease() {
    if (gitflow.isReleaseBranch()) {
        String releaseVersion = git.getSimpleBranchName()
        String dockerReleaseVersion = releaseVersion.split("v")[1]

        stage('Build & Push Image') {
            withCredentials([usernamePassword(credentialsId: 'cesmarvin',
                    passwordVariable: 'CES_MARVIN_PASSWORD',
                    usernameVariable: 'CES_MARVIN_USERNAME')]) {
                // .netrc is necessary to access private repos
                sh "echo \"machine github.com\n" +
                        "login ${CES_MARVIN_USERNAME}\n" +
                        "password ${CES_MARVIN_PASSWORD}\" >> ~/.netrc"
            }
            def dockerImage = docker.build("cloudogu/${repositoryName}:${dockerReleaseVersion}")
            sh "rm ~/.netrc"
            docker.withRegistry('https://registry.hub.docker.com/', 'dockerHubCredentials') {
                dockerImage.push("${dockerReleaseVersion}")
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
            String controllerVersion = makefile.getVersion()
            GString targetOperatorResourceYaml = "target/${repositoryName}_${controllerVersion}.yaml"
            releaseId = github.createReleaseWithChangelog(releaseVersion, changelog, productionReleaseBranch)
            github.addReleaseAsset("${releaseId}", "${targetOperatorResourceYaml}")
            github.addReleaseAsset("${releaseId}", "${targetOperatorResourceYaml}.sha256sum")
            github.addReleaseAsset("${releaseId}", "${targetOperatorResourceYaml}.sha256sum.asc")
        }
    }
}

void make(String makeArgs) {
    sh "make ${makeArgs}"
}

// Select latest github asset release download
private void writeSetupConfig() {
    doguOperatorURL = sh "curl -s https://api.github.com/repos/cloudogu/k8s-service-discovery/releases/latest | jq '.assets[] | select(.name|match(\"k8s-dogu-operator_.*.yaml\")) | .browser_download_url'"
    serviceDiscoveryURL = sh "curl -s https://api.github.com/repos/cloudogu/k8s-dogu-operator/releases/latest | jq '.assets[] | select(.name|match(\"k8s-service-discovery_.*.yaml\")) | .browser_download_url'"

    script.writeFile file: 'k8s-ces-setup-config.yaml', text: """
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-ces-setup-config
  namespace: ecosystem
  labels:
    app: cloudogu-ecosystem
    app.kubernetes.io/name: k8s-ces-setup
data:
  k8s-ces-setup.yaml: |
    log_level: "DEBUG"
    dogu_operator_url: ${doguOperatorURL}
    service_discovery_url: ${serviceDiscoveryURL}
    etcd_server_url: https://raw.githubusercontent.com/cloudogu/k8s-etcd/develop/manifests/etcd.yaml
    etcd_client_image_repo: bitnami/etcd:3.5.2-debian-10-r0
    key_provider: pkcs1v15
    remote_registry_url_schema: default
"""
}

private void writeSetupJson() {
    script.writeFile file: 'setup.json', text: """
{
  "naming": {
    "fqdn": "192.168.56.2",
    "domain": "k3ces.local",
    "certificateType": "selfsigned",
    "relayHost": "asdf",
    "completed": true,
    "useInternalIp": false,
    "internalIp": ""
  },
  "dogus": {
    "defaultDogu": "postgresql",
    "install": [
      "official/ldap",
      "official/postfix",
      "official/cas"
    ],
    "completed": false
  },
  "admin": {
    "username": "admin",
    "mail": "admin@admin.admin",
    "password": "adminpw",
    "adminGroup": "cesAdmin",
    "completed": true,
    "adminMember": true,
    "sendWelcomeMail": false
  },
  "userBackend": {
    "dsType": "embedded",
    "server": "",
    "attributeID": "uid",
    "attributeGivenName": "",
    "attributeSurname": "",
    "attributeFullname": "cn",
    "attributeMail": "mail",
    "attributeGroup": "memberOf",
    "baseDN": "",
    "searchFilter": "(objectClass=person)",
    "connectionDN": "",
    "password": "",
    "host": "ldap",
    "port": "389",
    "loginID": "",
    "loginPassword": "",
    "encryption": "",
    "completed": true,
    "groupBaseDN": "",
    "groupSearchFilter": "",
    "groupAttributeName": "",
    "groupAttributeDescription": "",
    "groupAttributeMember": ""
  }
}
"""
}
// TODO Delete this method if the setup yaml will be available in github releases
private void writeSetupYaml() {
    script.writeFile file: 'setup.yaml', text: """
#
# The service makes the setup available via port 30080. We should switch to a LoadBalancer if we figure out how to
# solve out external IP assignment
#
apiVersion: v1
kind: Service
metadata:
  name: k8s-ces-setup
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
spec:
  type: NodePort
  ports:
    - name: setup
      port: 8080
      targetPort: setup-webui
      nodePort: 30080
  selector:
    app.kubernetes.io/name: k8s-ces-setup
---
#
# The deployment for the setup
#
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-ces-setup
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: k8s-ces-setup
  template:
    metadata:
      labels:
        app: k8s-ces-setup
        app.kubernetes.io/name: k8s-ces-setup
    spec:
      containers:
        - name: k8s-ces-setup
          image: "cloudogu/k8s-ces-setup:v0.6.0"
          env:
            - name: GIN_MODE
              value: release
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          startupProbe:
            httpGet:
              path: /api/v1/health
              port: setup-webui
            failureThreshold: 60
            periodSeconds: 10
          livenessProbe:
            failureThreshold: 5
            httpGet:
              path: /api/v1/health
              port: setup-webui
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /api/v1/health
              port: setup-webui
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          ports:
            - name: setup-webui
              containerPort: 8080
              protocol: TCP
          volumeMounts:
            - mountPath: /k8s-ces-setup.yaml
              name: k8s-ces-setup-config
              subPath: k8s-ces-setup.yaml
            - mountPath: /setup.json
              name: k8s-ces-setup-json
              subPath: setup.json
      volumes:
        - configMap:
            name: k8s-ces-setup-config
          name: k8s-ces-setup-config
        - configMap:
            name: k8s-ces-setup-json
            optional: true
          name: k8s-ces-setup-json
      serviceAccountName: k8s-ces-setup
      nodeSelector:
        kubernetes.io/os: linux
---
#
# The role provides the setup with all permissions  to get, list and create new namespaces.
#
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: k8s-ces-setup
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
rules:
  - apiGroups:
      - "*"
    resources:
      - "*"
    verbs:
      - "*"
---
#
# The cluster role helps the setup to provide the dogu operator with the dogu CRD
#
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-ces-setup-cluster-resources
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
    # Specify these labels to grant permissions to the admin default role
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
rules:
  # allow to install the dogu CRD from the dogu operator
  - apiGroups:
      - apiextensions.k8s.io
    resources:
      - customresourcedefinitions
    verbs:
      - create
      - patch
      - update
  - apiGroups:
      - rbac.authorization.k8s.io
    resources:
      - clusterroles
      - clusterrolebindings
    verbs:
      - create
      - patch
      - update
      - delete
  - apiGroups:
      - "*"
    resources:
      - ingressclasses
    verbs:
      - get
      - create
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-ces-setup-cluster-non-resources
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
    # Specify these labels to grant permissions to the admin default role
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
rules:
  # allow to install a metrics cluster role of the dogu operator
  # it would be more secure if this rule would be delegated from setup/dogu operator to the initial setup process
  - nonResourceURLs:
      - /metrics
    verbs:
      - create
      - patch
      - update
      - get
---
# The service account is a token mounted into our setup pod. This token is used as authentication token against the
# K8s cluster.
#
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-ces-setup
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
automountServiceAccountToken: true
---
#
# The role binding binds our role to our service account, and, thus, gives him all permission defined
# in that role.
#
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: k8s-ces-setup
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: k8s-ces-setup
subjects:
  - kind: ServiceAccount
    name: k8s-ces-setup
---
#
# The cluster role binding binds our cluster role to our service account, and, thus, gives him all permission defined
# in the cluster role.
#
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-ces-setup-cluster-resources
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k8s-ces-setup-cluster-resources
subjects:
  - kind: ServiceAccount
    name: k8s-ces-setup
    namespace: 'default'
---
#
# The cluster role binding binds our cluster role to our service account, and, thus, gives him all permission defined
# in the cluster role.
#
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-ces-setup-cluster-non-resources
  labels:
    app: k8s-ces-setup
    app.kubernetes.io/name: k8s-ces-setup
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k8s-ces-setup-cluster-non-resources
subjects:
  - kind: ServiceAccount
    name: k8s-ces-setup
    namespace: 'default'
---
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: k8s-ces-setup-finisher
spec:
  schedule: "* * * * *"
  successfulJobsHistoryLimit: 0
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: kubectl-container
              image: bitnami/kubectl:1.23.6
              command:
                - /bin/entrypoint.sh
              volumeMounts:
                - name: cleanup-script
                  mountPath: /bin/entrypoint.sh
                  readOnly: true
                  subPath: entrypoint.sh
          restartPolicy: Never
          serviceAccountName: k8s-ces-setup-finisher
          volumes:
            - name: cleanup-script
              configMap:
                defaultMode: 0540
                name: k8s-ces-setup-cleanup-script
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-ces-setup-cleanup-script
data:
  entrypoint.sh: "#!/bin/bash\\nSTATE=\$(kubectl get configmap k8s-setup-config -o jsonpath='{.data.state}');\\nif [[ ${STATE} == \\"installed\\" ]]; then \\n  kubectl delete configmap k8s-ces-setup-json || true\\n  kubectl delete configmap k8s-setup-config || true\\n  kubectl delete deployments,services,configmaps,secrets,roles,rolebindings,serviceaccounts -l app.kubernetes.io/name=k8s-ces-setup || true\\n  kubectl patch cronjob cleanup -p '{\\"spec\\" : {\\"suspend\\" : true }}'\\n  kubectl delete configmap k8s-ces-setup-cleanup-script\\n  kubectl delete cronjob k8s-ces-setup-finisher\\n  kubectl delete serviceaccount k8s-ces-setup-finisher\\n  kubectl delete rolebinding k8s-ces-setup-finisher\\nelse \\n  echo \\"setup seems not to be installed or successfully executed\\";\\nfi"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: k8s-ces-setup-finisher
  labels:
    app: k8s-ces-setup-finisher
    app.kubernetes.io/name: k8s-ces-setup-finisher
rules:
  - apiGroups:
      - "*"
    resources:
      - configmaps
      - services
      - secrets
      - deployments
      - roles
      - rolebindings
      - serviceaccounts
      - cronjobs
    verbs:
      - delete
      - get
      - list
  - apiGroups:
      - "*"
    resources:
      - cronjobs
    verbs:
      - patch
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-ces-setup-finisher
  labels:
    app: k8s-ces-setup-finisher
    app.kubernetes.io/name: k8s-ces-setup-finisher
automountServiceAccountToken: true
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: k8s-ces-setup-finisher
  labels:
    app: k8s-ces-setup-finisher
    app.kubernetes.io/name: k8s-ces-setup-finisher
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: k8s-ces-setup-finisher
subjects:
  - kind: ServiceAccount
    name: k8s-ces-setup-finisher

"""
}