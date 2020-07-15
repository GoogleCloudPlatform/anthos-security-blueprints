# Cloud Security Blueprints for Anthos


## [Introduction](#Introduction)
This repository contains the deployable assets that are part of the Google Cloud [Security blueprints ](https://cloud.google.com/architecture/blueprints/)for Anthos. The Google Cloud Security blueprints for Anthos are granular and address specific security postures.

The instructions and accompanying assets in this repo are for the following Google Cloud Security blueprints for Anthos:



*   [Enforcing Policies](https://cloud.google.com/architecture/blueprints/anthos-enforcing-policies-blueprint)
*   [Enforcing locality restrictions for clusters on Google Cloud](https://cloud.google.com/architecture/blueprints/anthos-enforcing-locality-restrictions-blueprint) 

The blueprints can be used in any combination.
Note: If you need to constraint what regions your clusters can be deployed to the steps detailed in the Enforcing locality restrictions blueprint should be followed first before using any other Anthos security blueprint.


## [Config overview](#Config-overview)

This repository for the set of blueprints is  to be used with a [structured Anthos config management repo](https://cloud.google.com/anthos-config-management/docs/concepts/repo) 

Example Anthos config management Structured repo configuration:


```



── config-root/ # directory ACM monitors for policy
   ├── README.md
   ├── system/ # configs for the Operator
   ├── namespaces/ configs for namespaces and namespace-scoped objects. Structure determines namespace inheritance
   ├── cluster/ #  configs for cluster scoped objects
   |    | - # Put Your Policy Controller constraints here
   └── clusterregistry/ # configs for cluster selectors - limits which clusters a config applies to 
       ├── cluster.mycluster.yaml
       ├── clusterregistry.select-location-clusterx.yaml
       └── clusterregistry.select-prod.yaml
```

## [QuickStart](#QuickStart)

We recommend you read through the full README but if you just want to get started


1.  Ensure the assumptions are met
1.  Follow the steps in prerequisites 
1.  Configure your workstation environment
1.  Clone the repo 
1.  Configure Cloud Platform IAM
1.  Follow the deployment steps 

If you have already implemented one of the Anthos specific blueprints for your Anthos clusters  in this series you do not need to repeat the prerequisites and deployment steps described in this README

The blueprints outlined in this repo are additive so you can apply multiple blueprints to your clusters.

Follow through the detailed deployment steps for each individual blueprint by following the steps detailed in the README for the specific blueprint folder.

If you wish to start from an end to end example follow the steps outlined in the example README that mostly closely meets the security posture you wish to apply to your clusters.


## [Assumptions](#Assumptions) 

*   You have your Project and network configuration configured for your use case
*   You have  the appropriate IAM permissions to configure project resources
*   You have an Anthos entitlement
*   You have created your [GKE On Google Cloud Clusters](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine) and/or your [GKE on-premises clusters](https://cloud.google.com/anthos/gke/docs/on-prem/how-to/install-overview-basic)  following the guidance in the  applicable hardening guides 
    *   [Hardening GKE on Google Cloud](https://cloud.google.com/anthos/gke/docs/on-prem/how-to/hardening-your-cluster)
    *   [Hardening GKE on-premises](https://cloud.google.com/anthos/gke/docs/on-prem/how-to/hardening-your-cluster)

Note: each blueprint in the series  assumes you have [Policy Controller](https://cloud.google.com/anthos-config-management/docs/concepts/policy-controller) installed which is a recommendation in the hardening guides


*   Each cluster has the [Anthos Config Management Operator installed](https://cloud.google.com/anthos-config-management/docs/how-to/installing) 
*   Network policies are required and you created your cluster with the  --enable-network-policy flag  . This step provides you with the ability to  implement firewall rules that restrict what traffic can flow between pods in a cluster
*   You have defined the namespaces and labels required for the pods. This provides you with a name scope that allows you to work with policies and Kubernetes service accounts
*   You have some familiarity with Anthos Config Management. If you have not used Anthos config Management before familiarise yourself by following the [quickstart](https://cloud.google.com/anthos-config-management/docs/quickstart)
*   You are familiar with git 


## [Prerequisites](#Prerequisites) 


### [Prepare your admin workstation[(#Prepare your admin workstation)] 

You can use Cloud Shell, a local machine or VM as your admin workstation 


#### 
**Tools for Cloud Shell as your Admin workstation ** {#tools-for-cloud-shell-as-your-admin-workstation}



*   [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#download-as-part-of-the-google-cloud-sdk)
*    [nomos CLI](https://cloud.google.com/anthos-config-management/downloads) for managing ACM across clusters
*   [Terraform >= 0.12.3](https://www.terraform.io/downloads.html)

#### 
**Tools for  a  local workstation as your Admin workstation ** {#tools-for-a-local-workstation-as-your-admin-workstation}

*    [Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/quickstarts)
*    [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#download-as-part-of-the-google-cloud-sdk)
*   [nomos CLI](https://cloud.google.com/anthos-config-management/downloads) for managing ACM across clusters
*   [Terraform >= 0.12.3](https://www.terraform.io/downloads.html)

#### 
**Installation instructions for Tools for your environment** 


##### 
Install Cloud SDK {#install-cloud-sdk}


This is pre installed if you are using Cloud Shell

The Google Cloud SDK is used to interact with your GCP resources. [Installation instructions](https://cloud.google.com/sdk/downloads) for multiple platforms are available online.


##### 
Install kubectl CLI {#install-kubectl-cli}

The kubectl CLI is used to interteract with both Kubernetes Engine and kubernetes in general. [Installation instructions](https://cloud.google.com/kubernetes-engine/docs/quickstart) for multiple platforms are available online.


##### 
Install the nomos CLI {#install-the-nomos-cli}

Install the [nomos CLI](https://cloud.google.com/anthos-config-management/downloads) for managing ACM across clusters


##### 
Install Terraform {#install-terraform}

Terraform is used to automate the manipulation of cloud infrastructure. Its [installation instructions](https://www.terraform.io/intro/getting-started/install.html) are also available online


#### **Authentication** 

After installing the gcloud SDK run gcloud init to set up the gcloud cli. When executing choose the correct region and zone

'gcloud init'

Ensure you are using the correct project  . Replace my-project-name with the name of your project

Where the project name is my-project-name

`gcloud config set project my-project-name`


## [Deployment](#Deployment) 

### Fork and clone this repo 

**Important :If you are implementing multiple blueprints you only need to clone the repo once**



1.  Fork this repo to your account
1.  In your terminal, clone this repo locally.

    '$ git clone https://github.com/<GITHUB\_USERNAME>/xyz.git


    $ cd xyz/docs/'


For production configurations ensure you have configured [a centralised repo ](https://cloud.google.com/anthos-config-management/docs/how-to/nomos-command#server-hooks)such as Cloud Source Repositories, GitHub, Gitlab  for use with Anthos Config manager.


### Configure ACM Operator with repo 

**Important : You only need to do this step once per cluster**

The ACM Operator must be given read access to git and configured to read from a git repository.   \
 
It is recommended to use a [deploy key](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys) to authenticate the ACM Operator with git. Using a deploy key attaches the public part of the key directly to the repo rather than to a personal user account.

Create a ssh keypair and register the public key with your git hosting provider. 


```
# create ssh key
ssh-keygen -t rsa -N '' -b 4096 -C <git_username> -f ~/.ssh/id_rsa.acm

# add key to your ssh agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa.acm

#### add contents of public key ~/.ssh/id_rsa.acm.pub to the repo in the github account you are using for your configs 
#### github.com > Your Profile > Repositories > Settings > Deploy Keys > Add Deploy Key
 Paste in contents   

# Set write access
Select Allow write access
Click Add Key

# verify access
ssh -i /path/to/private/key git@github.com
Hi <git username>! You've successfully authenticated, but GitHub does not provide shell access.


```


Add the private key to a secret "git-creds" in each of your clusters.


```
# create secret in operator
kubectl create secret generic git-creds \
--namespace=config-management-system \
--from-file=ssh=~/.ssh/id_rsa.acm
```


Each cluster's ACM operator must be configured to point to the config-root in anthos-security-blueprints

Each cluster has its own config in the [setup/] directory.



1.  Create a copy of  the template YAML file named mycluster-config-managment.yaml  in the setup/ folder of your cloned repo for each of the clusters you wish to apply any  blueprints from this repo to  naming the copy to reflect the name of your cluster
1.  Update  each of the copied files in [setup/](https://github.com/GoogleCloudPlatform/csp-config-management/blob/1.0.0/locality-specific-policy/setup) to include your cluster names replacing 'mycluster' with your cluster name  and  the syncRepo git username with yours. For example, if your github username is <code>[user@example.com](mailto:user@example.com)</code>  change each YAML file to include 

 ```
         git:
          syncRepo: git@github.com:user@example.com/csp-config-management.git

```


If you are using another git repo amend accordingly


1.  Remove the template file mycluster-config-managment.yaml 
1.   Sync the ACM Operator for your clusters by repeating the following steps for each cluster

    ```
    # Get kubeconfig credentials for your cluster
    $ gcloud container clusters get-credentials <cluster name> --zone <cluster zone>
    # Ensure kubectl is using correct context
    $ kubectl config get-context
    # Apply the configuration to your cluster
    $ kubectl apply -f setup/<cluster name>.config-management.yaml
    ```


3.  Confirm the sync was successful with `nomos status`

        For each cluster you should see the status set to SYNCED

-