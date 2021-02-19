#!/bin/bash
# Copyright 2021 Google LLC
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

# See instructions - if you use Anthos Config Management, recommended to leave 
# this to true to be able to generate multiple non-conflicting cluster 
# configurations. Set to false if applying directly with kubectl
MULTICLUSTER=true

# See instructions - if you already have a labeled cluster definition in your 
# Anthos Config Management tree for this cluster, create a unique cluster selector
# and enter the name below. Otherwise leave as is
export CLUSTER_SELECTOR="$CLUSTER_NAME"-selector 

### NO INPUT NEEDED BELOW HERE

# get credentials
gcloud container clusters get-credentials $CLUSTER_NAME 
# the DNS IP address is retrieved via a kubectl command from the current 
# context
export DNS_IP=$(kubectl get services --namespace kube-system kube-dns -o \
jsonpath='{.spec.clusterIP}')

# create output directory if it doesn't exist
mkdir -p output

# for multicluster, create clusterspecific filenames,
# cluster and clusterselector definitions and link them
if [ "$MULTICLUSTER" = true ]
then
  envsubst < default-deny/default-deny-nodelocaldns.yaml | sed -e 's/#configmanagement/configmanagement/' > output/default-deny-nodelocaldns-$CLUSTER_NAME.yaml
  mkdir -p output/clusterregistry
  cd kube-system/clusterregistry
  for f in *.yaml
  do
    envsubst < $f > ../../output/clusterregistry/${f%.yaml}-$CLUSTER_NAME.yaml
  done
  cd ../..
# for single cluster, just create single file replacing variables
else
  envsubst < default-deny/default-deny-nodelocaldns.yaml > output/default-deny-nodelocaldns.yaml
fi


