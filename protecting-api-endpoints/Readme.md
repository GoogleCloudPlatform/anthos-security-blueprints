# Anthos security blueprint: Protecting API endpoints - example approaches and implementation steps

This directory provides deployable assets for sample policies that can be used by enterprises when devising Anthos Service Mesh and Apigee API Management policies.

You should already have some knowledge of Kubernetes, Anthos Service Mesh and Apigee hybrid. You must have two Anthos GKE clusters created, one for Apigee hybrid and the other cluster to run your application workloads. You should also have Anthos Service Mesh installed and setup per the applicable [installation guide](https://cloud.google.com/service-mesh/docs/install). Typically, you will setup the Apigee hybrid and application workloads cluster in separate projects and use separate VPC networks. It is assumed that you have the necessary networking setup,
[VPC peering](https://cloud.google.com/vpc/docs/vpc-peering) or a [shared VPC](https://cloud.google.com/vpc/docs/shared-vpc) configured. You should also make sure that you have CA signed certificates generated to enable secure communication from the Apigee hybrid cluster to the workloads cluster.

The instructions in this README provide implementation steps for the approach you would take to protect the API endpoints of workloads running in your Anthos cluster. This file also provides instructions on the setup needed when working with the code files in this directory.

These instructions provide implementation steps for the following typical approaches to protect API endpoints:

- Anthos Service Mesh policy: Denying traffic unless explicitly allowed
- Anthos Service Mesh policy: Enabling mTLS in between services in the mesh
- Apigee API proxy: Applying baseline security policies to securely expose and manage your APIs
- Cloud Armor policies for the Apigee cluster

Other typical policies will be added to the current repository over time. To contribute, see [how to contribute](https://github.com/GoogleCloudPlatform/anthos-security-blueprints/blob/master/docs/contributing.md).

For background information on the security controls used, see Anthos security blueprint: [Protecting API endpoints](https://cloud.google.com/architecture/blueprints/anthos-protecting-api-endpoints-blueprint).


## Anthos Service Mesh policy: Denying traffic unless explicitly allowed

A best practice for enterprises is to deny all traffic in a namespace by default. You do this in two steps. You do this at the application mesh level by creating an authorization policy that denies all traffic to your services by default.

1. Define the namespaces and labels that are required for the Pods of your applications.
2. Copy the default-deny.yaml from the manifests directory and apply to the namespace in which you've deployed your sample workload.
3. Apply the policy to your workloads cluster

```bash
kubectl apply -f manifests/default-deny.yaml
```

Additionally, you define a network policy that selects all Pods within that namespace. To follow this best practice, you need to have a network policy that selects all Pods within that namespace, network policy samples are available in the [Restricting Traffic directory](https://github.com/GoogleCloudPlatform/anthos-security-blueprints/tree/master/restricting-traffic).

## Anthos Service Mesh Policies: Enabling mTLS in between services in the mesh

You define an authentication policy that enforces mTLS between services in the mesh. You have granular control on the services that employ mutual TLS.

You can apply this policy to your application workloads cluster by running:

```bash
kubectl apply -f manifests/enforce-mtls.yaml
```
**Note** To apply the policy to the namespace running your workloads, make sure to update the manifest to include your namespace. The sample
manifest deploys it in the *default* namespace

## Cloud Armor policies in the cluster running the Apigee hybrid runtime

Google Cloud Armor security policies help you protect your load-balanced applications from web-based attacks. Once you have configured a Google Cloud Armor [security policy](https://cloud.google.com/armor/docs/configure-security-policies), you can reference it using a BackendConfig

```yaml
    apiVersion: cloud.google.com/v1
    kind: BackendConfig
    metadata:
      namespace: default
      name: my-backendconfig
    spec:
      securityPolicy:
        name: "example-security-policy"
```
You can bind Cloud Armor security policies to services running in your cluster using a BackendConfig resource. To bind your service to a BackendConfig, you must annotate the service with:

```bash
beta.cloud.google.com/backend-config: '{"ports": {"http":"my-backendconfig"}}'
```
In the example above, the annotation follows the pattern
 <em>'{"ports": {
    "port-1":"backendconfig-1",
    "port-2":"backendconfig-2"
  }}' </em>

You could use "default" as the key if you want all ports within the Service to be associated with the my-backendconfig BackendConfig.

## Apigee API proxy: Applying baseline security policies to securely expose and manage your APIs

The *apigee-hybrid* directory provides sample API management policies that you can apply to your API proxies.

If you run the run.sh script, a reference Apigee API proxy will be deployed to your Apigee hybrid runtime to demonstrate connectivity over private networking to your application workload cluster. In addition, the API proxy will apply sample policies that are typically used for such solutions and architectures; demonstrating security controls referred to in the blueprint document.
The policies apply sample limits, such as a quota of 1000 requests per hour and a rate limit of 10 requests per minute.

Refer to the <em>apigee-hybrid</em> directory for details.


## Deploying the sample app

You can deploy the sample application in this directory to see how Apigee hybrid and Anthos Service Mesh can protect your API endpoints. Running the run.sh script deploys a [sample application](https://istio.io/latest/docs/examples/bookinfo/) composed of four separate microservices.

To illustrate how your API endpoints are secured using Apigee hybrid and Anthos Service Mesh, you create an API proxy for the <em>reviews</em> service in this example. When a request is sent to the API proxy, Apigee hybrid applies the defined policies to the request and forwards it to the service via the internal load balancer by making an HTTPS request to `https://[internal-lb-ip]/reviews/[product-number]` where **internal-lb-ip** is the IP of the Internal Load Balancer & **product-number** is a numeric product id for which the review is requested, such as 1,2,3 et cetera. You should make sure that you have CA signed certificates generated to enable [secure communication](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/#configure-a-tls-ingress-gateway-using-sds) in between your clusters.

Complete the following steps before running the script.

- Create the following environment variables, these are used by the run.sh script:

```bash
    export PROJECT_ID=[The project that the clusters are configured in]

    export WORKLOAD_CLUSTER=[The name of your app workloads Anthos cluster]
    export WORKLOAD_CLUSTER_REGION=[Region the clusters are running in]

    export APIGEE_RUNTIME_CLUSTER=[The name of your Apigee hybrid Anthos cluster]
    export APIGEE_RUNTIME_REGION=[The name of the region for your zonal GKE cluster]
    export APIGEE_RUNTIME_ZONE=[The name of a zone within your selected region]
```

The following command will run the script:

```bash
./run.sh
```

Running this script will perform the following:

- In your workloads cluster it will:
  - Annotate the default namespace to enforce sidecar injection
  - Enforce mTLS for services running in your default namespace
  - Deploy the sample application in the default namespace
  - Update the virtual service created for the *reviews* app to make this service
    accessible to the gateway
  - Annotate the istio-ingressgateway service to use an internal load balancer. The Apigee hybrid runtime
    is able to reach the services running (and exposed) in this cluster via the internal load balancer

- In your Apigee hybrid cluster it will:
  - Install and setup Apigee hybrid
  - Install Cert Manager
  - Deploy an API proxy for the reviews application deployed in the workloads cluster along with sample API management policies