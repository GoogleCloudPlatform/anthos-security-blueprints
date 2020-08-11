# kube-system network policy templates for GKE


The templates in this directory are for a set of network policies that you can deploy together to allow the minimum required traffic to and from all Pods in the `kube-system` namespace.   
The current document shows snippets from the policy files and explains how the snippets implement traffic restrictions. It also indicates places where the policies need to be customized for your cluster. You customize those policy files automatically by configuring and running a script (`gen-kube-system-policies.sh`) as part of the implementation steps in the README in the parent directory. For details about deploying the policies and customizing them using the script, see the section "Restricting traffic in the `kube-system` namespace" in that README file.   
**Warning:** This approach is experimental and should not be used in production. It has been tested only on default installations of GKE version 1.16.8-gke.15 on Google Cloud. When used with any other version, it  might lead to failures of elements of the `kube-system` namespace. Disable [automatic control plane upgrades](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-upgrades#upgrading_automatically), because this setting will lead to failures after an upgrade. Also, because the policies reference cluster specifics such as control plane IP addresses and node subnet IP address ranges, changing these elements (for example, through [control plane IP rotation](https://cloud.google.com/kubernetes-engine/docs/how-to/ip-rotation) or [expanding subnets](https://cloud.google.com/vpc/docs/using-vpc#expand-subnet)) can lead to failure of these policies. 

## Organization of the policies

The policies in this directory are templates that are intended to be deployed together. They contain placeholders for cluster specifics in the form of environment variables. You can deploy the policies by following the instructions in the README file in the `~/anthos-security-blueprints/restricting-traffic/` subdirectory of this repo.  
The `~/anthos-security-blueprints/restricting-traffic/kube-system/` directory contains the following files:

-  `default-deny-all-egress.yaml` and `default-deny-all-ingress.yaml`: the default-deny policies for egress and ingress traffic for all Pods.
-  `allow-kubedns-from-all-egress.yaml`: a policy that allows all Pods to issue DNS requests.
-  `allow-<podname>-ingress.yaml`: an ingress policy for each Pod in the `kube-system` namespace that requires ingress traffic. (One YAML file for each Pod.)
-  `allow-<podname>-egress.yaml`: an egress policy for each Pod in the `kube-system` namespace. (One YAML file for each Pod.)

Because network policies don't apply to Pods running with the `hostNetwork:true` setting, there are no policies for Pods within the `kube-system` namespace that use the host network. To get a list of the pods that have this setting, run the following command:

```
kubectl get pods --all-namespaces \
-o custom-columns=NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork \
| grep true
```

## Policy explanations 

This section explains what kind of traffic the policies in this directory allow.  
Several Pods in the `kube-system` namespace require egress access to one or more of the following:

-  The Kubernetes control plane or Kubernetes API server
-  The [metadata server](https://cloud.google.com/compute/docs/storing-retrieving-metadata) 
-  Google APIs such as the Cloud Logging API or the Cloud Monitoring API

The policy snippets that allow this traffic are explained in this section. They apply to multiple policy files in the repo.  
Following these explanations, the section has explanations for policies for Pods that require traffic to pass to or from other destinations.

### Default-deny policy

The default-deny policy denies all ingress and egress traffic within the namespace unless the traffic is allowed by any other policy. Because Kubernetes network policies are additive, you need to deploy the default-deny policy at the same time as the other policies.  
You establish a default-deny policy by using two policy files:  `default-deny-ingress.yaml` and `default-deny-egress.yaml`. If you want to deploy only ingress policies, deploy only the `default-deny-ingress.yaml` file.  
The following listing shows the relevant content from the `default-deny-ingress.yaml` file:

```
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny-all-ingress
  namespace: kube-system
spec:
  policyTypes:
  - Ingress
  podSelector: {}
```

And the following snippet shows the relevant content from the `default-deny-egress.yaml` file: 

```
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny-all-egress
  namespace: kube-system
spec:
  policyTypes:
  - Egress
  podSelector: {}
```

### Allowing traffic from all Pods to kube-dns

All Pods in the `kube-system` namespace need to be able to send DNS requests (UDP and TCP port 53) to [`kube-dns`](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#kube-dns). You enable this by deploying the policy that's in the `allow-kubedns-from-all-egress.yaml` file, which contains the following policy specification:

```
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-kubedns-dns-from-all-egress
  namespace: kube-system
spec:
  podSelector: {} 
  policyTypes:
  - Egress
  egress: 
  - to:
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### Allowing traffic to the metadata server/proxy

Multiple Pods in the `kube-system` namespace need to send HTTP (port 80) requests to the [GCE instance metadata](https://cloud.google.com/compute/docs/storing-retrieving-metadata) server.  
When [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) or [metadata concealment](https://cloud.google.com/kubernetes-engine/docs/how-to/protecting-cluster-metadata#concealment) are enabled, these requests are intercepted by the [GKE metadata server](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#using_from_your_code) or by the [metadata proxy](https://github.com/GoogleCloudPlatform/k8s-metadata-proxy), which also run in `kube-system` on port 988 on every node.   
Because the network policy is applied after this traffic is redirected to port 988 on the local host, you need to apply two policy rules. One rule allows traffic to port 988 on localhost (`127.0.0.1`) which is required in case Workload Identity or the metadata proxy are enabled. The other rule allows traffic to port 80 on `169.254.169.254`, which is the IP address for the metadata server and is used for requests passing to the metadata server directly.  
In GKE version 1.16.8-gke.15, the following Pods that have the `hostnetwork:false` setting need access to the metadata server:

-  `event-exporter`
-  `kube-dns`
-  `stackdriver-metadata-agent-cluster-level`

The egress policies for those Pods is defined in the set of `allow-<podname>-egress.yaml` files (where `<podname>` represents each of the Pods in the preceding list.) The following snippet is included in all of these files; it shows part of the egress policy to allow access to the metadata server.

```
egress: 
  - to:
    - ipBlock:
        cidr: 127.0.0.1/32
    ports:
    - protocol: TCP
      port: 988
   - ipBlock:
        cidr: 169.254.169.254/32
    ports:
    - protocol: TCP
      port: 80
```

### Allowing traffic from specific Pods to the Kubernetes API server

Several Pods need access to the [Kubernetes API server](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/) to retrieve or modify data using the Kubernetes control plane. The Kubernetes API server is reachable on port 443.   
The customization script (`gen-kube-system-policies.sh`) in the parent directory of this README sets the policy to allow access to the IP address of your cluster-specific Kubernetes API server. The script performs the following steps:

1. Gets the IP address of the API server using the following command:

```
kubectl get endpoints --namespace default kubernetes
```

1. In the policy, replaces `${APISERVER_IP}` with the API server's IP address.

**Note:** You can perform these steps manually, but we recommend that you use the script for convenience.  
In GKE version 1.16.8-gke.15, the following Pods that don't run in hostnetwork need access to API server:

-  `calico-node-autoscaler`
-  `calico-typha-autoscaler`
-  `config-management-operator`
-  `event-exporter`
-  `fluentd-gke-scaler`
-  `kube-dns`
-  `kube-dns-autoscaler`
-  `metrics-server`
-  `stackdriver-metadata-agent-cluster-level`

The egress policies for those Pods is defined in the set of `allow-<podname>-egress.yaml` files (where `<podname>` represents each of the Pods in the preceding list.) The following snippet is included in all of these files; it shows part of the egress policy to allow access to `kube-apiserver`.

```
 egress: 
  - to:
    - ipBlock:
        cidr: ${APISERVER_IP}/32
    ports:
    - protocol: TCP
      port: 443
```

### Allowing traffic from specific Pods to Google APIs

Several Pods need access to Google Cloud Platform APIs through TLS (port 443), such as `monitoring.googleapis.com` and `logging.googleapis.com`. Because all APIs share IP addresses, you can't restrict access by API.   
By default, Google APIs might use any of a [large number of external IP addresses](https://cloud.google.com/vpc/docs/configure-private-google-access#ip-addr-defaults), which makes it impractical to filter by IP address. You can filter using network policies only if you allow all external traffic to port 443 (that is, your filter is set to the IP address range `0.0.0.0/0`). This is not recommended.  
However, if you use [Private Google Access](https://cloud.google.com/vpc/docs/private-access-options) with [Custom DNS zones](https://cloud.google.com/vpc/docs/configure-private-google-access#config-domain), you can restrict traffic to four IP addresses. You can use  `private.googleapis.com` (`199.36.153.8/30`) or `restricted.googleapis.com` (`199.36.153.4/30`), depending on whether you're using [VPC service controls](https://cloud.google.com/vpc/docs/configure-private-google-access#config).  
[Configure the DNS zones as described](https://cloud.google.com/vpc/docs/configure-private-google-access#config-domain) for `private.googleapis.com` or `restricted.googleapis.com` before you apply the network policies.  
The policy contains a placeholder (`${GOOGLEAPIS_CIDR}`) for the IP addresses that you need, which depends on how you've configured the DNS zones. When you run the script to customize the policy, the script replaces `${GOOGLEAPIS_CIDR}` with the following values:

-  If you're using `private.googleapis.com`, `${GOOGLEAPIS_CIDR}` is replaced with `199.36.153.8/30`.
-  If you're using `restricted.googleapis.com`, `${GOOGLEAPIS_CIDR}` is replaced with `199.36.153.4/30`.
-  If no custom DNS zones have been configured, `${GOOGLEAPIS_CIDR}` is replaced with `0.0.0.0/0`. In that case, all traffic to port 443 is allowed.

In GKE version 1.16.8-gke.15, the following Pods that don't run in `hostnetwork` need access to Google APIs:

-  `event-exporter`
-  `kube-dns`
-  `stackdriver-metadata-agent-cluster-level`

The egress policies for those Pods is defined in the set of `allow-<podname>-egress.yaml` files (where `<podname>` represents each of the Pods in the preceding list.) The following snippet is included in all of these files; it shows part of the egress policy to allow access to Google APIs. The script customizes these files to include the Google APIs IP address range as described earlier. 

```
  egress: 
  - to:
    - ipBlock:
        cidr: ${GOOGLEAPIS_CIDR}
    ports:
    - protocol: TCP
      port: 443
```

### Allowing DNS traffic for kube-dns

[`kube-dns`](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#kube-dns) takes DNS requests (UDP and TCP port 53) from all Pods in all namespaces. It either resolves the DNS requests directly or forwards them; on Google Cloud, it forwards the requests to the [Compute Engine internal DNS](https://cloud.google.com/compute/docs/internal-dns) service.  
The following snippet that's part of the `allow-kubedns-ingress.yaml` file ensures that DNS traffic from all other Pods and namespaces (but not those that are external to the cluster) can be received by `kube-dns`:

```
ingress:
  - from:
    - namespaceSelector: {}
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

The following snippet in the `allow-kubedns-egress.yaml` file allows outgoing traffic to `169.254.169.254`, which is the IP address of the internal DNS service.

```
egress: 
  - to:
    - ipBlock:
        cidr: 169.254.169.254/32
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

**Note:** If you use a [kube-dns configmap](https://kubernetes.io/blog/2017/04/configuring-private-dns-zones-upstream-nameservers-kubernetes/), you might have to add your upstream nameservers as additional `ipBlock` statements in this file.

### Allowing load balancer traffic for l7-default-backend

[`l7-default-backend`](https://github.com/kubernetes/ingress-gce/tree/master/cmd/404-server) (also called 404-server) acts as a default backend for the [GKE Ingress controller](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress) and serves a 404 response if there is no backend. `l7-default-backend` receives traffic on port 8080 from [external HTTP(S) Load Balancing](https://cloud.google.com/load-balancing/docs/https) and [internal HTTP(S) Load Balancing](https://cloud.google.com/load-balancing/docs/l7-internal).   
  
For internal HTTP(S) Load Balancing, you need to add the CIDRs of the [proxy-only subnets you create](https://cloud.google.com/load-balancing/docs/l7-internal/proxy-only-subnets) to the policy.  
The following snippet from the `allow-l7-default-backend-ingress.yaml` file allows incoming traffic from the current [source IP addresses for external HTTP(S) Load Balancing](https://cloud.google.com/load-balancing/docs/https#source_ip_addresses).

```
  ingress:
  - from:
     - ipBlock:
        cidr: 35.191.0.0/16
     - ipBlock:
        cidr: 130.211.0.0/22
    ports:
    - protocol: TCP
      port: 8080
```

### Allowing kubelet and API server traffic for metrics-server

[`metrics-server`](https://github.com/kubernetes-sigs/metrics-server) collects metrics from the kubelet on each host and makes the metrics available through the Kubernetes API server. The metrics are exposed on port 443 and are accessed by the Kubernetes API server. They're collected from the kubelet on each node in the cluster on port 10255.  
When you run the script to customize the network policies for your cluster, the script replaces `${NODE_CIDR}` with the primary IP address range of the subnet in which the GKE nodes reside. It gets the range with the following commands:

```
SUBNET_NAME=`gcloud container clusters describe [CLUSTER_NAME] --format='value(networkConfig.subnetwork)'`
gcloud compute networks subnets describe $SUBNET_NAME --format='value(ipCidrRange)'
```

As in other policy files, the script replaces `${APISERVER_IP}` with the API server IP address, which it gets by using the following command:

```
kubectl get endpoints --namespace default kubernetes
```

The following snippet in the `allow-metrics-server-ingress.yaml` file allows incoming traffic from all nodes and the API server on port 443. The script updates the `${APISERVER_IP}` placeholder as described earlier.

```
  ingress:
  - from:
     - ipBlock:
        cidr: ${APISERVER_IP}/32
    ports:
    - protocol: TCP
      port: 443
```

The following snippet in the `allow-metrics-server-egress.yaml` file allows outgoing traffic to the kubelet that runs on port 10255 on nodes. The script updates the `${NODE_CIDR}` placeholder as described earlier.

```
  egress: 
  - to:
    - ipBlock:
        cidr: ${NODE_CIDR}
    ports:
    - protocol: TCP
      port: 10255
```