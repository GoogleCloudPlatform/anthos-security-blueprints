#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# See README.md in parent directory for instructions on how to use this
# script

# set project id
gcloud config set project [PROJECT]
# set the cluster region or zone
gcloud config set compute/region [REGION]
gcloud config set compute/zone [ZONE]

# set the cluster name
export CLUSTER_NAME=[CLUSTER_NAME]

# See instructions - set to true to generate ingress and egress policies
# if set to false only ingress policies are created
GENERATE_EGRESS=true

# See instructions - if you use Anthos Config Management, recommended to leave 
# this to true to be able to generate multiple non-conflicting cluster 
# configurations. Set to false if applying directly with kubectl
MULTICLUSTER=true

# See instructions - choose the CIDR for accessing *.googleapis.com based on
# which option for Private Google Access and Custom DNS zones you are using
# uncomment the next line if mapping *.googleapis.com to private.googleapis.com   
export GOOGLEAPIS_CIDR=199.36.153.8/30
# uncomment the next line if mapping *.googleapis.com to restricted.googleapis.com
#export GOOGLEAPIS_CIDR=199.36.153.4/30
# uncomment the next line if using Public IP addresses to access *.googleapis.com 
# (no Custom DNS zones)
#export GOOGLEAPIS_CIDR=0.0.0.0/0

# See instructions - if you already have a labeled cluster definition in your 
# Anthos Config Management tree for this cluster, create a unique cluster selector
# and enter the name below. Otherwise leave as is
export CLUSTER_SELECTOR="$CLUSTER_NAME"-selector 

### NO INPUT NEEDED BELOW HERE

# get credentials
gcloud container clusters get-credentials $CLUSTER_NAME 
# the APISERVER IP address is retrieved via a kubectl command from the current 
# context
export APISERVER_IP=$(kubectl get endpoints --namespace default kubernetes -o \
jsonpath='{.subsets[0].addresses[0].ip}')

# The NODE CIDR is retrieved by getting the subnet in which the cluster is
# deployed
export SUBNET_NAME=$(gcloud container clusters describe $CLUSTER_NAME --format='value(networkConfig.subnetwork)')
export NODE_CIDR=$(gcloud compute networks subnets describe $SUBNET_NAME --format='value(ipCidrRange)')

# create output directory if it doesn't exist
mkdir -p output
cd kube-system
# if generating egress, select all files, otherwise just ingress files
if [ "$GENERATE_EGRESS" = true ]
then
  FILE_SELECTOR="*.yaml"
else
  FILE_SELECTOR="*-ingress.yaml"
fi 

# for multicluster, create clusterspecific filenames,
# cluster and clusterselector definitions and link them
if [ "$MULTICLUSTER" = true ]
then
  for f in $FILE_SELECTOR 
  do 
    envsubst < $f | sed -e 's/#configmanagement/configmanagement/' > ../output/${f%.yaml}-$CLUSTER_NAME.yaml
  done
  mkdir -p ../output/clusterregistry
  cd clusterregistry
  for f in *.yaml
  do
    envsubst < $f > ../../output/clusterregistry/${f%.yaml}-$CLUSTER_NAME.yaml
  done
  cd ..
# for single cluster, just create template files replacing variables
else
  for f in $FILE_SELECTOR
  do 
    envsubst < $f > ../output/$f
  done
fi
cd ..
