# Instructions for clusters with NodeLocal DNSCache without Dataplane V2

This file provides instructions for the "Denying traffic unless it is explicitly allowed" use case when using
GKE clusters that have NodeLocal DNSCache enabled and are not using Dataplane V2.
For other GKE clusters, follow the instructions in the main README.md file.

## Denying traffic unless it is explicitly allowed

In Kubernetes, all traffic to and from any Pod is allowed unless there is an explicit network policy in the namespace and the policy selects (matches) the Pod. Network policies are additive. If any policies select a Pod, the Pod is restricted to what is allowed by the union of the ingress and egress rules in those policies.   
A best practice for enterprises is to deny all traffic in a namespace by default. To follow this best practice, you need to have a network policy that selects all Pods within that namespace. Traffic is then allowed only when it is explicitly permitted by other network policies in that namespace. However, you need to allow DNS traffic to pass to the DNS service in the `kube-system` namespace or you will break DNS discovery within the cluster. You can inspect the policy before deploying it by looking at the `default-deny/default-deny-nodelocaldns.yaml` file.  
To implement a policy of denying all traffic except DNS traffic to the DNS service, carry out the following steps in your [structured Anthos config management repo](https://cloud.google.com/anthos-config-management/docs/concepts/repo). If you've already carried out some of the steps, such as defining your namespace hierarchy, you can skip those steps.


1. Define the namespaces and labels that are required for the Pods of your applications.
1. Prepare your namespace hierarchy under your `~/config-root/namespaces` directory. For more information, see [Configuring namespaces and namespace-scoped objects](https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects).
1. If there is no Anthos Config Management namespace config for `kube-system`, create a `~/config-root/namespaces/kube-system` directory and add the namespace definition by copying `kube-system.yaml` from the directory that contains this README file to the new directory.

   If there is a namespace definition already, add the following label to the existing namespace config in the `~/config-root/namespaces/kube-system `directory:

   ```
   labels:
     k8s-namespace: kube-system
   ```

   Labeling the `kube-system` namespace is required so that the `kube-dns` Pod in the `kube-system` namespace is selected by a network policy.


Because the network policy references the DNS service for your clusters, you have to create network policies that are customized for each cluster. For every cluster in which you want deny traffic unless it is explicitly allowed, perform the following steps:

1. Edit the `gen-default-deny-nodelocaldns.sh` file and make the following changes:

   -  Replace `[PROJECT]` with the ID of the Google Cloud project that contains your cluster.
   -  Replace `[REGION]` and `[ZONE]` with your cluster's region and zone (for a regional cluster, you can comment out the line that defines the zone).
   -  Replace `[CLUSTER_NAME]` with the name of your GKE cluster.
   -  If you want to restrict only ingress traffic and allow all egress traffic from `kube-system`, `c`hange `GENERATE_EGRESS` to `false`.
   -  Change `MULTICLUSTER` to `false` to generate configs that don't have a cluster selector. This is not recommended, and you should do this only if you don't use Anthos Config Management and want to apply these policies manually using `kubectl`.
   -  If you've already created [`Cluster` and `ClusterSelector` definitions](https://cloud.google.com/anthos-config-management/docs/how-to/clusterselectors) for your cluster, change the line that sets the `CLUSTER_SELECTOR` environment variable to a ClusterSelector that uniquely identifies your cluster. Otherwise leave this value as is because the script will create the definitions.
1. Save the file you edited and run the `gen-default-deny-nodelocaldns.sh` script.
1. Inspect the cluster-specific policies that have been created in the `output/` directory.

Now copy the policies to your Anthos Config Management repo:

1. Copy all files in the `output/` directory to the appropriate namespaces or abstract namespaces in your Anthos Config Management repo.

   **Important:** Don't apply the policy to all namespaces by copying the files to the `~/config-root/namespaces`. If you do,  you might block the necessary GKE and Anthos Config Management traffic in the `kube-system` and `config-management-system` namespaces.

1. If you haven't yet created `[Cluster` and `ClusterSelector` definitions](https://cloud.google.com/anthos-config-management/docs/how-to/clusterselectors) for your cluster, copy all files in the `output/clusterregistry/` directory to the `~/config-root/clusterregistry` directory.

Apply your [network policy](https://cloud.google.com/anthos-config-management/docs/how-to/configs#network-policy-config) and constraints by using Anthos Config Management.
1. Create a commit that includes the files you have just created and then push the commit to the remote repository:
   ```
   git add namespaces/
   git add clusterregistry/
   git commit -m "add default deny policy"
   git push
   nomos status --poll 2s
   ```

   The `nomos status` command monitors your enrolled clusters. When you see the sync status return as **Synced**, the policies have been applied.
1. Press `Ctrl+C` to exit the `status` command. If you see any [error messages](https://cloud.google.com/anthos-config-management/docs/reference/errors), resolve them and repeat these steps.
