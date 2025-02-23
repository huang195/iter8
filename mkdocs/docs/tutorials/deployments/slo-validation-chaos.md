# SLO Validation with Chaos Injection

!!! tip "Inject Chaos into Kubernetes cluster and validate if app can satisfy SLOs"
    **Problem:** You have a Kubernetes app. You want to stress test it by injecting chaos, and verify that it can satisfy service-level objectives (SLOs). This helps you guarantee that your application is resilient, and works well even under periods of stress (like intermittent pod failures).

    **Solution:** You will launch a Kubernetes application along with a Helm chart consisting of a [Litmus Chaos](https://litmuschaos.io/) experiment, and an Iter8 experiment. The chaos experiment will delete pods of the application periodically, while the Iter8 experiment will send requests to the app and verify if it is able to satisfy SLOs.

    ![Chaos with SLO Validation](../../images/slo-validation-chaos.png)

???+ warning "Setup Kubernetes cluster and local environment"
    1. Complete the [getting started tutorial](../../getting-started/first-experiment.md) (highly recommended), and skip to step 7 below.
    2. Setup [Kubernetes cluster](../../getting-started/setup-for-tutorials.md#local-kubernetes-cluster)
    3. [Install Iter8 in Kubernetes cluster](../../getting-started/install.md)
    4. Get [Helm 3.4+](https://helm.sh/docs/intro/install/).
    5. Get [`iter8ctl`](../../getting-started/install.md#install-iter8ctl)
    6. Fork the [Iter8 GitHub repo](https://github.com/iter8-tools/iter8). Clone your fork, and set the `ITER8` environment variable as follows.
    ```shell
    export USERNAME=<your GitHub username>
    ```
    ```shell
    git clone git@github.com:$USERNAME/iter8.git
    cd iter8
    export ITER8=$(pwd)
    ```
    7. Install [Litmus](https://litmuschaos.io/) in Kubernetes cluster.
    ```shell
    kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v1.13.8.yaml
    ```
    Verify that Litmus is install correctly as described [here](https://v1-docs.litmuschaos.io/docs/getstarted/#install-litmus).

## 1. Create app
The `hello` app consists of a Kubernetes deployment and service. Deploy the app as follows.

```shell
kubectl apply -n default -f $ITER8/samples/deployments/app/deploy.yaml
kubectl apply -n default -f $ITER8/samples/deployments/app/service.yaml
```

Use [these instructions](../../getting-started/first-experiment.md#1a-verify-app-is-running) to verify that your app is running.

## 2. Launch joint experiment
```shell
helm upgrade -n default my-exp $ITER8/samples/deployments/chaos \
  --set applabel='app.kubernetes.io/name=hello' \
  --set URL='http://hello.default.svc.cluster.local:8080' \
  --set limitMeanLatency=50.0 \
  --set limitErrorRate=0.0 \
  --set limit95thPercentileLatency=100.0 \
  --install
```

The above command creates a [Litmus chaos experiment](https://litmuschaos.io/) and an [Iter8 experiment](../../concepts/whatisiter8.md#what-is-an-iter8-experiment). The former injects chaos into your environment by periodically killing pods of your app. The latter generates HTTP requests, collects latency and error rate metrics for the app, and verifies if the app satisfies mean latency (50 msec), error rate (0.0), 95th percentile tail latency (100 msec) SLOs, even in the midst of chaos.

View the manifest created by the Helm command, the default values used by the Helm chart, and the actual values used by the Helm release using [the instructions in this step](../../getting-started/first-experiment.md#2a-view-manifest-and-values).

## 3. Observe Experiment
Observe the Iter8 experiment by following [these steps](../../getting-started/first-experiment.md#3-observe-experiment). You can also observe the chaos experiment as follows.

Verify that the phase of the chaos experiment is `Completed`.
```shell
export CHAOS=$(kubectl get chaosresults -o=jsonpath='{.items[0].metadata.name}' -n default)
kubectl get chaosresults/$CHAOS -n default -ojsonpath='{.status.experimentStatus.phase}'
```

Verify that the chaos experiment returned a `Pass` verdict. The `Pass` verdict states that the application is still running after chaos has ended.
```shell
kubectl get chaosresults/$CHAOS -n default -o=jsonpath='{.status.experimentStatus.verdict}'
```

Due to chaos injection, and the fact that the number of replicas of the app in the deployment manifest is set to 1, the SLOs are not expected to be satisfied during this experiment. Verify this is the case.
```shell
# this assertion is expected to fail
iter8ctl assert -c completed -c winnerFound -n default
```

## 4. Scale app and retry
Scale up the app so that replica count is increased to 2. 
```shell
kubectl scale --replicas=2 -n default -f $ITER8/samples/deployments/app/deploy.yaml
```

The scaled app is now more resilient. Performing the same experiment as above will now result in SLOs being satisfied and a winner being found. Retry steps 2 and 3 above. You should now find that SLOs are satisfied and a winner is found at the end of the experiment.

```shell
# this assertion is expected to succeed
iter8ctl assert -c completed -c winnerFound -n default
```

## 5. Cleanup
```shell
helm uninstall -n default my-exp
kubectl delete -n default -f $ITER8/samples/deployments/app/service.yaml
kubectl delete -n default -f $ITER8/samples/deployments/app/deploy.yaml
```

***

!!! tip "Reuse with your app"
    1. Reuse the above experiment with *your* app by replacing the `hello` app with *your* app, and modifying the Helm values appropriately.
    
    2. Litmus makes it possible to inject [over 51 types of Chaos](https://hub.litmuschaos.io/). Modify the Helm chart to use any of these other types of chaos experiments.

    3. Iter8 makes it possible to [promote the winning version](../../concepts/buildingblocks.md#version-promotion) in a number of different ways. Easily incorporate the following in your Helm chart.
        - [GitOps with automated pull request](slo-validation-pr.md)
        - [Auto trigger a GitHub Actions workflow](slo-validation-ghaction.md)