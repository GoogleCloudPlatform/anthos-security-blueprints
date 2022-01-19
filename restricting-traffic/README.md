# Anthos security blueprint: Restricting traffic - example approaches and implementation steps

This repository directory provides deployable assets and implementation steps for typical approaches that are used in enterprises to restrict traffic within Kubernetes clusters using sample network policies. These instructions provide prescriptive guidance for restricting traffic on the Anthos Platform and GKE.

You should already have some knowledge of Kubernetes [network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/). We assume that you have an Anthos or GKE cluster with network policies enabled and a [structured Anthos Config Management repository](https://cloud.google.com/anthos-config-management/docs/concepts/repo). If you use privately used public IP addresses (PUPI), make sure you [configure SNAT correctly](https://cloud.google.com/kubernetes-engine/docs/how-to/alias-ips#enable_pupis) for Network Policy to work. To prepare your workstation, follow the instructions in the README file in the root directory of the current repository.  
These instructions provide implementation steps for the following typical approaches to restrict traffic:

-  Denying traffic unless it is explicitly allowed.
-  Restricting internet access.
-  Restricting traffic in the `kube-system` namespace (for GKE on Google Cloud only).

Other typical approaches will be added to the current repository over time. To add your own approaches, see [how to contribute](https://github.com/GoogleCloudPlatform/anthos-security-blueprints/blob/master/docs/contributing.md).  
For background information on the security controls used, see [Anthos security blueprint: Restricting traffic](https://cloud.google.com/architecture/blueprints/anthos-restricting-traffic-blueprint).  

**Note:** When you're using Anthos on Google Cloud, you can also use [VPC firewall rules](https://cloud.google.com/vpc/docs/firewalls), [hierarchical firewall policies](https://cloud.google.com/vpc/docs/firewall-policies), and [organization policy constraints](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints) to restrict traffic and load-balancer creation for whole clusters or for individual teams. The implementation steps detailed do not include how to configure these features. For information about common approaches for deploying VPC firewall rules, see [Best practices and reference architectures for VPC design](https://cloud.google.com/solutions/best-practices-vpc-design).

## Denying traffic unless it is explicitly allowed

These instructions are for GKE clusters using Dataplane V2 or clusters not using NodeLocal DNScache. If you have GKE clusters using NodeLocal DNScache but not using Dataplane V2 (including GKE on prem) follow the instructions in README-nodelocaldns.md instead. For mixed environments follow both sets of instructions. 

Clusters that use NodeLocal DNScache but not Dataplane V2 can be identified by running the following command:

```
gcloud container clusters describe CLUSTER_NAME --format="table(addonsConfig.dnsCacheConfig.enabled:label='NodeLocalDNS',networkPolicy.provider:label='NetworkPolicy provider')"
```

In a cluster with NodeLocalDNS and without Dataplane V2 you will see the following output:

```
NodeLocalDNS  NetworkPolicy provider
True          CALICO
```


In Kubernetes, all traffic to and from any Pod is allowed unless there is an explicit network policy in the namespace and the policy selects (matches) the Pod. Network policies are additive. If any policies select a Pod, the Pod is restricted to what is allowed by the union of the ingress and egress rules in those policies.   
A best practice for enterprises is to deny all traffic in a namespace by default. To follow this best practice, you need to have a network policy that selects all Pods within that namespace. Traffic is then allowed only when it is explicitly permitted by other network policies in that namespace. However, you need to allow DNS traffic to pass to the `kube-dns` Pods in the `kube-system` namespace or you will break DNS discovery within the cluster. You can inspect the policy before deploying it by looking at the `default-deny/default-deny.yaml` file.  
To implement a policy of denying all traffic except DNS traffic to `kube-dns`, carry out the following steps in your [structured Anthos config management repo](https://cloud.google.com/anthos-config-management/docs/concepts/repo). If you've already carried out some of the steps, such as defining your namespace hierarchy, you can skip those steps.

1. Define the namespaces and labels that are required for the Pods of your applications.
1. Prepare your namespace hierarchy under your `~/config-root/namespaces` directory. For more information, see [Configuring namespaces and namespace-scoped objects](https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects).
1. If there is no Anthos Config Management namespace config for `kube-system`, create a `~/config-root/namespaces/kube-system` directory and add the namespace definition by copying `kube-system.yaml` from the directory that contains this README file to the new directory.

   If there is a namespace definition already, add the following label to the existing namespace config in the `~/config-root/namespaces/kube-system `directory:

   ```
   labels:
     k8s-namespace: kube-system
   ```

   Labeling the `kube-system` namespace is required so that the `kube-dns` Pod in the `kube-system` namespace is selected by a network policy.

1. Copy the `default-deny.yaml` file from the `default-deny` subdirectory to the appropriate namespaces or abstract namespaces in your Anthos Config Management repo.

   **Important:** Don't apply the policy to all namespaces by copying the file to the `~/config-root/namespaces`. If you do,  you might block the necessary GKE and Anthos Config Management traffic in the `kube-system` and `config-management-system` namespaces.

1. If you want to use the policy only in a subset of your clusters, use [cluster labels and cluster selectors](https://cloud.google.com/anthos-config-management/docs/how-to/clusterselectors) and modify the configuration accordingly.

Apply your [network policy](https://cloud.google.com/anthos-config-management/docs/how-to/configs#network-policy-config) using Anthos Config Management:

1. Create a commit that includes the files you have just created and then push the commit to the remote repository:

   ```
   git add namespaces/
   git commit -m "add default deny policy"
   git push
   nomos status --poll 2s
   ```

   The `nomos status` command monitors your enrolled clusters. When you see the sync status return as **Synced**, the policies have been applied. 

1. Press `Ctrl+C` to exit the `status` command. If you see any [error messages](https://cloud.google.com/anthos-config-management/docs/reference/errors), resolve them and repeat these steps.

## Restricting internet access 

If you want to make sure that your Kubernetes workloads will never be exposed to the internet—that is, they don't allow either ingress or egress—you can follow the approach described in this section that's a combination of the following:

-  A network policy that allows traffic only to the private IP address space as defined in [RFC 1918](https://tools.ietf.org/html/rfc1918). You can inspect this network policy by looking at the `no-internet/no-internet.yaml` file in the current repo. 

   This policy allows traffic for all Pods to and from all cluster-internal targets as well as to and from all private IP addresses. However, because network policies are additive, after you apply the first network policy you cannot deny any of this traffic using other network policies. If you don't want to allow all cluster-internal traffic, start with the default-deny policy mentioned in the previous section.

-  A constraint that uses the `k8snoexternalservices` constraint template from the [Anthos Policy Controller constraint template library](https://cloud.google.com/anthos-config-management/docs/reference/constraint-template-library#etc). You can inspect the constraint by looking at the `no-internet/no-internet-services.yaml` file in the current repo.

To implement this approach, carry out the following steps in your [structured Anthos config management repo](https://cloud.google.com/anthos-config-management/docs/concepts/repo). If you've already carried out some of the steps, such as defining your namespace hierarchy, you can skip those steps.

1. Define the namespaces and labels that are required for the Pods of your applications.
1. Prepare your namespace hierarchy under the `~/config-root/namespaces` directory. For more information, see [Configuring namespaces and namespace-scoped objects](https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects).
1. Copy the `no-internet.yaml` policy file from the `no-internet` subdirectory to the appropriate namespaces or abstract namespaces in your Anthos Config Management repo. This policy allows all traffic within private address ranges. Modify the policy if you're using non-RFC 1918 ranges for private addresses. 

   **Important:** Don't apply the policy to all namespaces by copying the file to the `~/config-root/namespaces`. If you do, you might block the necessary GKE and Anthos Config Management traffic in the `kube-system` and `config-management-system` namespaces.

1. Copy the `no-internet/no-internet-services.yaml` constraint to the `cluster/` directory in your Anthos Config Management repo. If you're using non-RFC 1918 ranges for private addresses, modify the constraint.
1. If you want to use the policy only in a subset of your clusters use [cluster labels and cluster selectors](https://cloud.google.com/anthos-config-management/docs/how-to/clusterselectors) and modify the configuration accordingly.

Apply your [network policy](https://cloud.google.com/anthos-config-management/docs/how-to/configs#network-policy-config) and constraint using Anthos Config Management:

1. Create a commit that includes the files you have just created and then push the commit to the remote repository:

   ```
   git add namespaces/
   git commit -m "add no internet network policy and constraint"
   git push
   nomos status --poll 2s
   ```

   The `nomos status` command monitors your enrolled clusters. When you see the sync status return as **Synced,** the policies have been applied.

1. Press `Ctrl+C` to exit the `status` command. If you see any [error messages](https://cloud.google.com/anthos-config-management/docs/reference/errors), resolve them and repeat these steps.

## Restricting traffic in the kube-system namespace

If your security policy requires network policies to be deployed in all namespaces, including the  `kube-system` namespace, you can use the approach described in this section to restrict traffic within the namespace to required traffic only.  
**Warning:** This approach is experimental and should not be used in production. It has been tested only on default installations of GKE version 1.16.8-gke.15 on Google Cloud. When used with any other version, it  might lead to failures of elements of the `kube-system` namespace. Disable [automatic control plane upgrades](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-upgrades#upgrading_automatically), because this setting will lead to failures after an upgrade. Also, because the policies reference cluster specifics such as control plane IP addresses and node subnet IP address ranges, changing these elements (for example, through [control plane IP rotation](https://cloud.google.com/kubernetes-engine/docs/how-to/ip-rotation) or [expanding subnets](https://cloud.google.com/vpc/docs/using-vpc#expand-subnet)) can lead to failure of these policies.   
The policy templates are in the `~/anthos-security-guardrails/restricting-traffic/kube-system/` subdirectory of the current repo. For an explanation of how these policies are organized and what traffic is allowed, see the `README` file in that directory. The implementation steps are explained in this document.  
To implement this approach, carry out the following steps in your [structured Anthos config management repo](https://cloud.google.com/anthos-config-management/docs/concepts/repo). If you've already carried out some of the steps, such as defining your namespace hierarchy, you can skip those steps.

1. Define the namespaces and labels that are required for the Pods of your applications.
1. Prepare your namespace hierarchy under the `~/config-root/namespaces` directory. For more information, see  [Configuring namespaces and namespace-scoped objects](https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects).

Because the network policies reference the API server and subnetwork for your clusters, you have to create network policies that are customized for each cluster. For every cluster in which you want to restrict `kube-system` traffic, perform the following steps:

1. Edit the `gen-kube-system-policies.sh` file and make the following changes:

   -  Replace `[PROJECT]` with the ID of the Google Cloud project that contains your cluster.
   -  Replace `[REGION]` and `[ZONE]` with your cluster's region and zone (for a regional cluster, you can comment out the line that defines the zone).
   -  Replace `[CLUSTER_NAME]` with the name of your GKE cluster.
   -  If you want to restrict only ingress traffic and allow all egress traffic from `kube-system`, `c`hange `GENERATE_EGRESS` to `false`.
   -  Change `MULTICLUSTER` to `false` to generate configs that don't have a cluster selector. This is not recommended, and you should do this only if you don't use Anthos Config Management and want to apply these policies manually using `kubectl`.
   -  Uncomment one of the following 3 lines that define `GOOGLEAPIS_CIDR`, depending on the [Private Google Access](https://cloud.google.com/vpc/docs/private-access-options) method that's used in your project:
      -  If you're using `private.googleapis.com`, uncomment the line containing `199.36.153.8/30`
      -  If you're using `restricted.googleapis.com`, uncomment the line containing `199.36.153.4/30`
      -  If you're not using DNS zones for Google APIs, uncomment the line containing `0.0.0.0/0` . This is not recommended, because it allows all egress traffic from Pods that need Google API access on port 443.
   -  If you've already created [`Cluster` and `ClusterSelector` definitions](https://cloud.google.com/anthos-config-management/docs/how-to/clusterselectors) for your cluster, change the line that sets the `CLUSTER_SELECTOR` environment variable to a ClusterSelector that uniquely identifies your cluster. Otherwise leave this value as is because the script will create the definitions.
1. If you haven't already [configured the DNS zones as described](https://cloud.google.com/vpc/docs/configure-private-google-access#config-domain) for `private.googleapis.com `or `restricted.googleapis.com` and want to use one of those access methods, configure them now.
1. Save the file you edited and run the `gen-kube-system-policies.sh` script.
1. Inspect the cluster-specific policies that have been created in the `output/` directory.

Now copy the policies to your Anthos Config Management repo:

1. If there is no namespace config for kube-system, create a `~/config-root/namespaces/kube-system` directory and add the namespace definition by copying `kube-system.yaml` from the current repo to the current directory.
1. Copy all files in the `output/` directory to the  `~/config-root/namespaces/kube-system` directory.
1. If you haven't yet created [`Cluster` and `ClusterSelector` definitions](https://cloud.google.com/anthos-config-management/docs/how-to/clusterselectors) for your cluster, copy all files in the `output/clusterregistry/` directory to the `~/config-root/clusterregistry` directory.

Apply your [network policy](https://cloud.google.com/anthos-config-management/docs/how-to/configs#network-policy-config) and constraints by using Anthos Config Management.
1. Create a commit that includes the files you have just created and then push the commit to the remote repository:
   ```
   git add namespaces/
   git add clusterregistry/
   git commit -m "add kube-system policies"
   git push
   nomos status --poll 2s
   ```

   The `nomos status` command monitors your enrolled clusters. When you see the sync status return as **Synced**, the policies have been applied.
1. Press `Ctrl+C` to exit the `status` command. If you see any [error messages](https://cloud.google.com/anthos-config-management/docs/reference/errors), resolve them and repeat these steps.
