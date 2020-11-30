# Anthos Security blueprint: Enforcing policy - implementation steps

IMPORTANT: To be able to successfully follow the instructions detailed here you must have followed the setup steps detailed in the  ~/anthos-blueprints/README.md in the repo.

These instructions provide a prescriptive way to enforce policies in your Anthos GKE clusters

Refer to the accompanying  [Anthos Google Cloud security blueprint Enforcing policies](https://cloud.google.com/architecture/blueprints/anthos-enforcing-policies-blueprint) to understand the features you will configure following the steps detailed below.

Note: If you have already carried out some of the steps such as defining your namespace hierarchy you can skip those steps when you get to them .

Note the implementation steps do not include  configuration steps for applying [resource quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/) as configuring resource quotas has a hard dependency on your application profile. 

The steps detailed below are carried out using your local admin workstation which you configured in the prepare your admin workstation prerequisites steps detailed in the  ~/anthos-blueprints/README.md

## Applying Network policies - managing traffic flow between pods

Network policies are namespace-scoped, and can only be placed in namespace directories or abstract namespaces. Network policies are additive. If any policy or policies select a pod, the pod is restricted to what is allowed by the union of those policies’ ingress/egress rules. Thus, order of evaluation does not affect the policy result.

In the local clone of the repo carry out the following:

1. Define the namespaces and labels that are required for the pods your application is deployed to.
1.  Prepare your namespace hierarchy under your ~/config-root/namespaces folder.  For guidance refer to

    <https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects>

1. Identify the network policies that most closely meet your needs from [kubernetes network policy recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)
1. Create YAML file(s)  from the  [kubernetes network policy recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)
that most closely meets your requirement

1. Name the file(s) to reflect what the network policy is enforcing.
1. Modify the YAML file(s) you have created  to meet your requirements ( At least by changing labels to reflect your configuration ) 
1.   Move the YAML file you just created to the appropriate folder under your ~/config-root/namespaces/

Apply your [network policy](https://cloud.google.com/anthos-config-management/docs/how-to/configs#network-policy-config) by using Anthos Config Management.

   8. Create a commit that includes the Network policy config file(s) you have just created push the commit to the remote repository.

```
git add namespaces/your-namespace-folder/yourpolicy.yaml
git commit -m "Create network policy config "
git push
nomos status --poll 2s
```

The nomos status command monitors your enrolled clusters When you see the sync status return as Synced the policies have successfully been applied . Press Ctrl-c to exit  If you observe any [error messages](https://cloud.google.com/anthos-config-management/docs/reference/errors) resolve and repeat this step

## Enforcing compliance with policies

Applying policies using Policy Controller needs careful planning so ensure you understand the implications of applying the constraints.  We suggest running policies in ["dryrun" mode ](https://cloud.google.com/anthos-config-management/docs/how-to/creating-constraints#dryrun)to audit results before enforcing on production workloads.

### Enforcing labels  

In the local clone of the repo carry out the following:

Use the [constraint template library](https://github.com/open-policy-agent/gatekeeper-library/tree/master/library/general) to enforce labels

9. Make a copy of the file ~/anthos-blueprints/enforcing-policies/enforce-label.yaml
1. Edit the copy to reflect your requirements and copy it into the appropriate place under the config-root/namespaces folder hierarchy
1. Validate that the policy file is valid by using nomos vet

`nomos vet --path=/path/to/local-repo/`

 If the command returns silently then the Policy file being applied is valid

12. Apply the policy by committing and pushing the changes

```
git add .
git commit -m "add policy Enforcing labels in dryrun mode"
git push  
nomos status --poll 2s`
 ```

The nomos status command monitors your enrolled clusters. When you see the sync status return as Synced the policies have successfully been applied . Press Ctrl-c . If you observe any error messages resolve and repeat this step

13. Audit the policy by watching the constraint object for status changes


    `kubectl get \ 
    K8sRequiredLabels.constraints.gatekeeper.sh [CONSTRAINT-NAME] -o yaml -w`

    Verify that the results are appropriate for your workload. 

 14. Update the constraint to enforce the policy by changing the `enforcementAction` to `deny` and pushing to git.

```
git add .
git commit -m "update policy Enforcing \labels to deny mode"
git push  
nomos status --poll 2s`
```


  15. Test the constraint manually by attempting to push an object that violates the policy.

	
`kubectl apply -f anthos-blueprints/enforcing-policies/enforce-label.example.yaml
   `
Expected output:

    Error from server([denied by [CONSTRAINT-NAME]]...

### Enforcing PodSecurity policies

In the local clone of the repo carry out the following:

Use the [ constraint template library](https://github.com/open-policy-agent/gatekeeper-library/tree/master/library/pod-security-policy) to enforce Pod security policies

For maintainability applying each constraint individually is required.

16.   Navigate to the folder for this blueprint ~/Blueprints/enforcing-policies

Download the set of PodSecurity policy constraint files from the constraint template library by running the get-podsecurity-policy.sh shell script


```
chmod +x get-podsecurity-policy.sh
./get-podsecurity-policy.sh
```

17.  move the constraint files to config-root/cluster

Following best practice the constraints are set to dryrun mode. Setting enforcementAction to dryrun allows you to validate the impact of the policy. 

18.  Validate that each policy file is valid by using nomos vet 

    `nomos vet --path=/path/to/local-repo/`


If the command returns silently then they are valid

19.  Apply the policies by committing and pushing the changes

```
git add .
git commit -m "add PodSecurity policy constraints"
git push 
nomos status --poll 2s`
 ```

The nomos status command monitors your enrolled clusters When you see the sync status return as Synced the policies have successfully been applied . If you observe any error messages resolve and repeat this step 

   When you are satisfied that the implementation of the PodSecurity  policies will not inadvertently impact the availability of your application set the policy files to enforcement mode  by changing the value for enforcementAction from  'dryrun' to 'deny' in each of the policy files. Then apply the updated policies.

Note:  You can test each of the PodSecurity policies by using the example.yaml file in each policy constraint folder in the [ constraint template library](https://github.com/open-policy-agent/gatekeeper-library/tree/master/library/pod-security-policy) 

20. Copy the example.yaml file  or its contents to your local workstation , use kubectl to try and apply it.

`kubectl apply -f  example.yaml `

You should get an error returned as Policy Controller enforced the policy .

## Anthos Service Mesh configuration - Enforcing mTLS   

You can apply additional controls that focus at the application layer (L7) to further enforce policies by using Anthos Service Mesh. To enforce mTLS within the service mesh follow the steps in this section that apply to your GKE clusters:


21.   Install Anthos service mesh to your cluster enforcing strict mTLS mode
  
   For Anthos GKE on-prem follow the guidance detailed in  [Anthos GKE on-prem Installing Anthos Service mesh in  strict mTLS mode](https://cloud.google.com/service-mesh/docs/gke-on-prem-install#strict-mtls)
  
   For Anthos GKE on Google cloud follow the guidance detailed in [Anthos GKE on Google cloud: installing Anthos service mesh in strict mTLS mode](https://cloud.google.com/service-mesh/docs/gke-install-existing-cluster#strict-mtls)

Apply a constraint policy to ensure that[ mTLS is on](https://github.com/GoogleCloudPlatform/acm-policy-controller-library/tree/master/anthos-service-mesh/peer-authentication).

22.    Copy the contents from [peer authentication template](https://github.com/GoogleCloudPlatform/acm-policy-controller-library/blob/master/anthos-service-mesh/peer-authentication/template.yaml) to a local file named mtls-on-template.yaml  in the top level of your local repo this is the constraint template
2.  [Install the constraint template](https://cloud.google.com/anthos-config-management/docs/how-to/write-a-constraint-template#installing_your_constraint_template) you have created 

`kubectl apply -f mtls-on-template.yaml`

  Create a constraint to enforce mTLS on your cluster using the constraint template you have created

24.   Copy the contents from [peer authentication constraint ](https://github.com/GoogleCloudPlatform/acm-policy-controller-library/blob/master/anthos-service-mesh/peer-authentication/constraint.yaml)to a file named mtls-on.yaml  , move it to  config-root/cluster 
    
25. Validate that the policy  constraint file is valid by using nomos vet 

`nomos vet --path=/path/to/local-repo/`

  If the command returns silently then they are valid

26.  Apply the policies by committing and pushing the changes

```
git add .
git commit -m "add PodSecurity policy constraints"
git push 
nomos status --poll 2s
```

The nomos status command monitors your enrolled clusters When you see the sync status return as Synced the policies have successfully been applied . If you observe any error messages resolve and repeat this step 

27.   When you are satisfied that the implementation of the  policy  will not inadvertently impact the availability of your application modify the policy constraint  file to enforcement mode   by changing the value for enforcementAction from  'dryrun' to 'deny' and commit and push the modified files to your repo.