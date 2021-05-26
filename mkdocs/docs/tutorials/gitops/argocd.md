---
template: main.html
---

# GitOps with Argo CD

!!! tip "Scenario: GitOps"
    GitOps methodology is increasingly used in CI/CD pipelines in Kubernetes-based environments to ease cluster management tasks. In GitOps, Git repos are used as the source-of-truth for the desired state of one or more clusters, and a CD pipeline tool is used to continuously monitor changes in the repos and sync them to the clusters. Additionally, it is preferred that these Git repos are structured in a certain way so the code repo is separated from the environment (Env) repo. Commits to the code repo trigger the CI pipeline to build, test, lint, and eventually push newly built images to an image repository. Env repo contains resource files that describe how various resources should be deployed to the cluster. When a newly built image becomes available, files in the Env repo are updated, at which time, the CD pipeline will start syncing the changes to the clusters.

    Iter8 can be used in the context of GitOps so that new versions of an application can be first thoroughly tested before rolling them out to various environments. In this tutorial, we will use Argo CD as the CD pipeline tool and Istio as the underlying service mesh, and we will cover the following topics:

    1. Show an example of Env repo setup for GitOps+Iter8
    2. Show how a CI pipeline updates the Env repo to start an Iter8 experiment
    3. Show how Iter8 updates Env repo after an experiment is finished to uphold GitOps guarantees

## Step 1. Create K8s cluster

If you don't already have a K8s cluster, create a Minikube or Kind K8s cluster locally by referring to step 1 of the [quick start tutorial](../../../getting-started/quick-start/#1-create-kubernetes-cluster). Otherwise, skip to the next step.

## Step 2. Fork repo

As you will need to make changes to the Env repo to test new app versions, you will need your own copy of the repo.

* Fork this repo: [https://github.com/iter8-tools/iter8](https://github.com/iter8-tools/iter8).
* Now you should have your own Env repo at https://github.com/[YOUR_ORG]/iter8.

## Step 3. Install platform components

In your K8s cluster, we will need to install Istio, Prometheus, Iter8, Argo CD. Run the following script to install these.

```shell
git clone https://github.com/[YOUR_ORG]/iter8.git
cd iter8
export ITER8=$(pwd)
$ITER8/samples/gitops/platformsetup.sh
```

## Step 4. Argo CD Setup (One time)

The output from the previous step will provide instructions on how to access Argo CD UI to setup your Argo CD app. You might see something similar to:

```shell
Your Argo CD installation is complete
Run the following commands:
    1. kubectl port-forward svc/argocd-server -n argocd 8080:443
    2. Open a browser with URL: http://localhost:8080 with the following credential
       Username: 'admin', Password: 'xxxxxxxxxx'
```

Start the port-forward in a new terminal, and access the Argo CD UI on your browser. After logging in, you should see Argo CD showing no application is currently installed. To install the new application, run:

```shell
kubectl apply -f $ITER8/samples/gitops/argocd-app.yaml
```

Now check in the Argo CD UI that a new `gitops` app is created, and it is showing both Healthy and Synced.

## Step 5. Setup Github token

At the end of an experiment, Iter8 will need to update Env repo so the winner of the experiment becomes the new baseline (it will also need to perform various clean up tasks in the Env repo -- we will discuss these later). To accomplish this, Iter8 will need to have access to your Env repo, so it can make the necessary changes by creating PRs. First, login to www.github.com, and from the upper right corner of the page, go to Settings > Developer settings > Personal access token > Generate new token. Make sure the token is granted access for `repo.public_repo`. Now copy the token, and make it into a K8s secret that Iter8 can use at runtime. Run (replace the token string with your own token):

```shell
kubectl create secret generic iter8-token --from-literal=token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Step 6. Start experiment

When a new image becomes available or when new configurations are to be used, CI pipeline (or some other entity) will make changes to the Env repo, so the new desired states are deployed into the cluster. Now that we want the new desired states to be first tested before fully rolling them out, the CI pipeline will need to make a few more changes in the Env repo. Specifically, it will need to create at least the following resources:

- Candidate deployment: contains updated container image, configurations, and/or environment variables
- Iter8 experiment: specifies baseline and candidate deployments, and how the experiment should run

Additionally, if a workload generator needs to be started, the CI pipeline should also create the appropriate resources in the Env repo.

To simplify this step, we included a `runCI.sh` script that creates these 3 resources to simulate what a CI pipeline would do. Just run:

```shell
$ITER8/samples/gitops/runCI.sh
git status -s
```

It should show something like the following

```shell
?? experiment.yaml
?? fortio.yaml
?? productpage-candidate.yaml
 M templates/version
```

The 3 new files created are Iter8 experiment, workload generator, and candidate deployment, respectively. The last file is used internally to keep track of the current version of the app, so on subsequent calls to `runCI.sh`, it can monotonically increment the app version to `v2`, `v3`, `v4`, etc. Alternatively, one can use git commit IDs as version numbers. 

To trigger Argo CD to deploy these new resources into the cluster and start the Iter8 experiment, one would need to commit the changes to the Env repo by running the following:

```shell
git add -A ./; git commit -m "iter8 experiment"; git push origin head
```

By default Argo CD is configured to run every 3 minutes, so if you don't want to wait, you can use Argo CD UI to force a manual refresh so the changes to Env repo can be immediately synced to the cluster. 

## 7. Finish experiment

The experiment should run for roughly 2 minutes once it starts, and one can run the following command to track its progress:

```
watch kubectl get experiments.iter8.tools gitops-exp
```

Once the experiment finishes, check https://github.com/[YOUR_ORG]/iter8/pulls. Iter8 should have created a new PR titled `Iter8 GitOps`. File diffs from the PR should show clearly what Iter8 is changing in the Env repo. Regardless which version is the winner, Iter8 will always clean up the Env repo after an experiment is finished. Specifically, the files created by the CI pipeline will be all deleted, i.e., experiment.yaml, fortio.yaml, and productpage-candidate.yaml, to essentially put the Env repo back to the inital state. Additionally, if the candidate met all the success criteria of the experiment, productpage.yaml will be updated to reflect an update to the baseline version.

You can now merge the PR that Iter8 just created. This will sync the Env repo to the new desired state of the cluster. If the experiment succeeded, the candidate version will become the new baseline for future experiments.

## 9. Cleanup
```shell
kubectl delete -f $ITER8/samples/gitops/
kubectl delete ns istio-system
kubectl delete ns iter8-system
kubectl delete ns argocd
```

## Additional details

### General GitOps+Iter8 guidelines

It's a generally a good idea to separate code repo from environment repo. If the same repo is being used, one needs to be careful to configure CI/CD pipeline so that changes to the repo doesn't create infinite loops.

### Pipeline integration


### Iter8 GitOps handler task

Iter8 operating in the context of GitOps is similar to how it operates normally, i.e., instead of relying on `kubectl apply`, actions are done by modifying the Env repo, and then the changes are applied indirectly to the cluster by the CD pipeline tool. However, a key distination is Iter8 in the context of GitOps has a specific finish handler task that is responsible for cleaning up the Env repo and updating the baseline version after experiments are finished.

For prototyping, one can write these handlers as shell scripts and inline them within an Experiment CR. This makes writing these handlers extremely efficient and easy to debug. However, the down side is it makes the Experiment CR a lot more complicated and scary to read. We are currently working to simplify the handler interface, so stay tuned.

### GitOps support for multiple environments

Some users might use GitOps to manage multiple environments, e.g., staging, pre-prod, prod, so changes are always propagated from environment to environment, minimizing the chance of problems reaching the prod environment. In this setup, the Iter8 GitOps handler task would need to be modified so that Env repo changes are done at the correct place. For example, if diffeent environments are managed by different Env repos, the handler task would need to make multiple git commits, one for each of the repos. This could be done all within a single handler task, or across multiple tasks.

### Caveats

1. Both CI pipeline and Iter8 now write to the Env repo, and if not coordinated, race condition could occur and cause corruption in the repo. We assume changes done in the Env repo are done via PRs, so the race conditions are minimized, if not eliminated. However, other means to coordinate writes to the Env repo by different entities can be done so fully  automated pipeline can be achieved.

2. When a new app version becomes available while an experiment is still running, the new experiment will preempt the existing one. We currently don't support `test-every-commit` behavior, but this could be supported in the future.

3. Iter8 handler code could fail. Error handling needs to be done carefully so failure doesn't create inconsistencies that would require manual fixing later.

