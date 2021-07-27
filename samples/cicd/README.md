# Iter8+GitOps in Openshift

This tutorial shows how to progressively roll out new versions of your app using Iter8 in a fully CI/CD setup in an Openshift cluster. A majority of the tutorial focuses on setting up Openshift cluster and a CI/CD pipeline, so if you already have this setup and just want to find out how to add Iter8's capability into your existing pipeline, you can skip ahead and focus only on steps x and y.

## Prereqs

### Openshift cluster

First, you will need an Openshift cluster. In this tutorial, we provisioned an Openshift cluster from [IBM Cloud](https://www.ibm.com/cloud). You can also use [CodeReady Container](https://developers.redhat.com/products/codeready-containers/overview) or [Openshift Playground](https://developers.redhat.com/courses/openshift/playground-openshift) to follow along.

### Fork the repo

As you will need to make changes to the Env repo to test new app versions, you will need your own copy of the repo.

* Fork this repo: [https://github.com/iter8-tools/iter8](https://github.com/iter8-tools/iter8)
* Now you should have your own Env repo at: https://github.com/[YOUR_ORG]/iter8

### Install Openshift Pipeline

We use Openshift Pipeline to manage CI tasks. It can be installed using its operator -- from IBM Cloud Console > Openshift > Cluster > [cluster name] > Openshift web console > Operators > OperatorHub > Red Hat OpenShift Pipelines Operator > Install. Once it's installed, you can check to make sure the Openshift Pipeline Operator and the Pipeline components are running in the cluster by running:

```shell
oc get pods -n openshift-operators
NAME                                            READY   STATUS    RESTARTS   AGE
openshift-pipelines-operator-7fdd8fff9f-sv5dj   1/1     Running   0          4m3s

oc get pods -n openshift-pipelines
NAME                                          READY   STATUS    RESTARTS   AGE
tekton-pipelines-controller-7c4b9bf4b-gmdpk   1/1     Running   0          75s
tekton-pipelines-webhook-6f666f55f7-s9wcv     1/1     Running   0          75s
tekton-triggers-controller-54f8c88b4b-lmrdb   1/1     Running   0          39s
tekton-triggers-webhook-c64fd9b47-pvtk8       1/1     Running   0          39s
```

### Install Openshift GitOps

We use Openshift GitOps to manage CD tasks. It can be installed using its operator -- from IBM Cloud Console > Openshift > Cluster > [my cluster] > Openshift web console > Operators > OperatorHub > Red Hat OpenShift GitOps > Install. Once it's installed, you can check to make sure the Openshift GitOps Operator and GitOps components are running in the cluster by running the following commands:

```shell
oc get pods -n openshift-operators
NAME                                            READY   STATUS    RESTARTS   AGE
gitops-operator-6bccf5bbdf-xcfkx                1/1     Running   0          17s
openshift-pipelines-operator-7fdd8fff9f-sv5dj   1/1     Running   0          4m3s

oc -n openshift-gitops get pods
NAME                                                    READY   STATUS    RESTARTS   AGE
argocd-cluster-application-controller-7fbb6d4f6-sv5q6   0/1     Running   0          2m
argocd-cluster-redis-74cc6c9f46-bslhp                   1/1     Running   0          2m
argocd-cluster-repo-server-65f74dddbb-pjmw5             1/1     Running   0          119s
argocd-cluster-server-84b95d5cc-29wlf                   0/1     Running   0          119s
kam-7974577cdc-hz5kb                                    1/1     Running   0          2m3s
```

You can access Openshift GitOps Web Console by first going to the Openshift Web Console > Application Stages (at the top) > ArgoCD, or you can do a `port-forward` locally, i.e.,

```shell
oc port-forward -n openshift-gitops svc/argocd-cluster-server 8080:443
```

and then open a web browser to http://localhost:8080. In either case, you will need an `admin` password to login to ArgoCD Web Console, and the password can be obtained with the following command:

```shell
oc -n openshift-gitops  get secret argocd-cluster-cluster -o jsonpath="{.data.admin\.password}" | base64 -d
```

Leave the Openshift GitOps Web Console open for now.

### Install Iter8

To install Iter8:

```shell
git clone http://github.com/[YOUR_ORG]/iter8
cd iter8
export ITER8=`pwd`
$ITER8/samples/cicd/iter8-setup.sh
```

### Update references

Your will need to update a few reference links to correctly point them to `[YOUR_ORG]`:

```shell
find $ITER8/samples/cicd -name "*.yaml" -type f | xargs sed -i '' "s/MY_ORG/YOUR_ORG/"
sed -i '' "s|ROUTE_ADDRESS|`oc -n openshift-ingress get services router-default -o jsonpath="{.status.loadBalancer.ingress[0].ip}"`|" $ITER8/samples/cicd/templates/fortio.yaml
git commit -a -m "update reference links"
git push origin head
```

### Instantiate CI pipeline

To instantiate a CI pipeline, run:

```shell
oc apply -f $ITER8/samples/cicd/tekton/tasks
oc apply -f $ITER8/samples/cicd/tekton
oc expose service el-iter8-eventlistener
echo "Openshift ingress IP: `oc get route el-iter8-eventlistener --template='http://{{.spec.host}}'`"
```

To trigger the above CI pipeline on a PR merge, go to github.com/[YOUR_ORG]/iter8 > Settings > Webhooks > Add webhook, and set the following:
* Payload URL: `Copy the Openshift ingress IP from above`
* Content type: `application/json`
* Which event: `Let me select individual event > Select Pull request and Unselect Pushes`

Now whenever a PR is merged to the `master` branch, our CI pipeline will run. We will describe what runs in the pipeline a bit later.

### Setup Github token

Components in the CI/CD pipeline will need to modify your Github repo via creating PRs, and you need to provide authentication to it by creating a Github Personal Access Token. Go to github.com > upper right corner > Settings > Developer settings > Personal access token > Generate new token

Copy the token and make a Kubernetes secret from it so it can be used at runtime by the CI/CD pipeline.

```shell
oc create secret generic github-token --from-literal=token=[Github token]
```

### Setup Prometheus access token

Use the Oauth token for `oc login` to access metrics from Prometheus server, we create a K8s secret:

```shell
oc create secret generic promsecret --from-literal=token=[Oauth token]
```

## Deploy app 

```shell
oc apply -f $ITER8/samples/cicd/rbac.yaml
oc apply -f $ITER8/samples/cicd/argocd-app.yaml
```

On Argo CD Web Console, it should show that a new app called `gitops` is created. Make sure it is showing both Healthy and Synced - this might take a few minutes.

## Start a progressive rollout

Now that our application is deployed in the cluster, CI/CD pipeline configured to watch for commits from Github, it is time to see what happens when a developer merges a PR.

Modifies samples/cicd/app/server.py

```shell
git checkout -b test
git commit -a -m "v2"
git push origin head
```

Go to github.com/[YOUR_ORG]/iter8, create a PR from the above commit, and merge it. Check if the pipeline is triggered by:

```shell
oc get pipelineruns
```

If everything goes well, the pipeline will add a few more resources to the Env repo. These changes will be eventually detected by Openshift GitOps and start the progressive rollout. One can check its progress with

```shell
watch iter8ctl describe
```
