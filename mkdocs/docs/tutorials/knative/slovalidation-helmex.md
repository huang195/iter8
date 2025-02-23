---
template: main.html
---

# SLO validation

!!! tip "Scenario: Safely rollout new version of a Knative app with SLO validation"
    [Dark launch](../../concepts/buildingblocks.md#dark-launch) a candidate version of your Knative application, [validate that the candidate satisfies latency and error-based objectives (SLOs)](../../concepts/buildingblocks.md#slo-validation), and promote the candidate.
    
    This tutorial illustrates the [Helm-based experiment pattern](../../concepts/whatisiter8.md#iter8-and-helm).
    
    ![SLO validation](../../images/yourfirstexperiment.png)

??? warning "Setup K8s cluster with Knative and local environment"
    1. Get [Helm 3.4+](https://helm.sh/docs/intro/install/) 
    2. Setup [K8s cluster](../../getting-started/setup-for-tutorials.md#local-kubernetes-cluster).
    3. [Install Knative in K8s cluster](setup-for-tutorials.md#local-kubernetes-cluster). This tutorial can be tried with any Knative networking layer.
    4. [Install Iter8 in K8s cluster](../../getting-started/install.md)
    5. Get [`iter8ctl`](../../getting-started/install.md#get-iter8ctl)
    6. Get [the Iter8 Helm repo](../../getting-started/setup-for-tutorials.md#iter8-helm-repo)

## 1. Create baseline version
Deploy the baseline version of the `hello world` application using Helm.

```shell
helm install my-app iter8/knslo \
  --set baseline.dynamic.tag="1.0" \
  --set baseline.dynamic.id="v1" \
  --set candidate=null
```

??? note "View K8s resources created by Helm"
    Use the command below to view the K8s resources created by Helm during the release of `my-app`.
    ```shell
    helm get manifest my-app
    ```

??? note "Verify that baseline version is 1.0.0"
    Ensure that the Knative app is ready.
    ```shell
    kubectl wait ksvc/hello --for=condition=Ready
    ```

    Port-forward the ingress service for Knative. With the `Kourier` networking layer, you can do this as follows.
    === "Kourier"
        ```shell
        # do this in a separate terminal
        kubectl port-forward svc/kourier -n knative-serving 8080:80
        ```

    ```shell
    curl localhost:8080 -H "Host: hello.default.example.com"
    ```

    ```
    # output will be similar to the following (notice 1.0.0 version tag)
    # hostname will be different in your environment
    Hello, world!
    Version: 1.0.0
    Hostname: hello-bc95d9b56-xp9kv
    ```

## 2. Create candidate version
Deploy the candidate version of the `hello world` application using Helm.

```shell
helm upgrade my-app iter8/knslo \
  --set baseline.dynamic.tag="1.0" \
  --set baseline.dynamic.id="v1" \
  --set candidate.dynamic.tag="2.0" \
  --set candidate.dynamic.id="v2" \
  --install
```

The above command creates [an Iter8 experiment](../../concepts/whatisiter8.md#what-is-an-iter8-experiment) alongside the candidate version of the `hello world` application. The experiment will collect latency and error rate metrics for the candidate, and verify that it satisfies the mean latency (50 msec), error rate (0.0), 95th percentile tail latency (100 msec) SLOs.

??? note "Verify that candidate version is 2.0.0"
    Ensure that the Knative app is ready.
    ```shell
    kubectl wait ksvc/hello --for=condition=Ready
    ```

    ```shell
    # this command reuses the port-forward from the first step
    curl localhost:8080 -H "Host: candidate-hello.default.example.com"
    ```

    ```
    # output will be similar to the following (notice 2.0.0 version tag)
    # hostname will be different in your environment
    Hello, world!
    Version: 2.0.0
    Hostname: hello-bc95d9b56-xp9kv
    ```

## 3. Observe experiment
Describe the results of the Iter8 experiment. Wait ~1 min before trying the following command. If the output is not as expected, try again after a few seconds.

```shell
iter8ctl describe
```

??? info "Experiment results will look similar to this ... "
    ```shell
    ****** Overview ******
    Experiment name: my-experiment
    Experiment namespace: default
    Target: my-app
    Testing pattern: Conformance
    Deployment pattern: Progressive

    ****** Progress Summary ******
    Experiment stage: Completed
    Number of completed iterations: 1

    ****** Winner Assessment ******
    > If the version being validated; i.e., the baseline version, satisfies the experiment objectives, it is the winner.
    > Otherwise, there is no winner.
    Winning version: my-app

    ****** Objective Assessment ******
    > Identifies whether or not the experiment objectives are satisfied by the most recently observed metrics values for each version.
    +--------------------------------------+--------+
    |              OBJECTIVE               | MY-APP |
    +--------------------------------------+--------+
    | iter8-system/mean-latency <=         | true   |
    |                               50.000 |        |
    +--------------------------------------+--------+
    | iter8-system/error-rate <=           | true   |
    |                                0.000 |        |
    +--------------------------------------+--------+
    | iter8-system/latency-95th-percentile | true   |
    | <= 100.000                           |        |
    +--------------------------------------+--------+

    ****** Metrics Assessment ******
    > Most recently read values of experiment metrics for each version.
    +--------------------------------------+--------+
    |                METRIC                | MY-APP |
    +--------------------------------------+--------+
    | iter8-system/mean-latency            |  1.233 |
    +--------------------------------------+--------+
    | iter8-system/error-rate              |  0.000 |
    +--------------------------------------+--------+
    | iter8-system/latency-95th-percentile |  2.311 |
    +--------------------------------------+--------+
    | iter8-system/request-count           | 40.000 |
    +--------------------------------------+--------+
    | iter8-system/error-count             |  0.000 |
    +--------------------------------------+--------+
    ``` 

## 4. Promote winner
Assert that the experiment completed and found a winning version. If the conditions are not satisfied, try again after a few seconds.

```shell
iter8ctl assert -c completed -c winnerFound
```

Promote the winner as follows.

```shell
helm upgrade my-app iter8/knslo \
  --set baseline.dynamic.tag="2.0" \
  --set baseline.dynamic.id="v2" \
  --set candidate=null \
  --install
```

??? note "Verify that baseline version is 2.0.0"
    Ensure that the Knative app is ready.
    ```shell
    kubectl wait ksvc/hello --for=condition=Ready
    ```

    ```shell
    curl localhost:8080 -H "Host: hello.default.example.com"
    ```

    ```
    # output will be similar to the following (notice 2.0.0 version tag)
    # hostname will be different in your environment
    Hello, world!
    Version: 2.0.0
    Hostname: hello-bc95d9b56-xp9kv
    ```

## 5. Cleanup

```shell
helm uninstall my-app
```

***

**Next Steps**

!!! tip "Use in production"
    The `knslo` Helm chart is located in the `$ITER8/helm` folder. Modify the chart as needed by your application for production usage.

!!! tip "Try other Iter8 Knative tutorials"
    * [SLO validation with progressive traffic shift](testing-strategies/slo-validation-traffic-shift.md)
    * [Hybrid testing](testing-strategies/hybrid.md)
    * [Fixed traffic split](rollout-strategies/fixed-split.md)
