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


# Setup kubeconfig
function set_up_credentials {
  gcloud container clusters get-credentials ${WORKLOAD_CLUSTER} --region $WORKLOAD_CLUSTER_REGION --project ${PROJECT_ID}
  kubectl config rename-context gke_${PROJECT_ID}_${WORKLOAD_CLUSTER_REGION}_${WORKLOAD_CLUSTER} ${WORKLOAD_CLUSTER}
}

# Annotate "default" namespace in the WORKLOAD_CLUSTER to enforce sidecar injection
function enforce_sidecar_injection {
  kubectl --context=${WORKLOAD_CLUSTER} label namespace default istio-injection=enabled --overwrite
  echo "Sidecar injection enabled"
}

# Enforce mTLS for services running the "default" namespace in the WORKLOAD_CLUSTER
function enforce_mtls_in_namespace {
  kubectl --context=${WORKLOAD_CLUSTER} apply -n default -f manifests/enforce-mtls.yaml
  echo "mTLS enforced in namespace"
}

# Deploy sample application
function deploy_sample_app {
  kubectl --context=${WORKLOAD_CLUSTER} apply -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml
  kubectl --context=${WORKLOAD_CLUSTER} apply -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/networking/destination-rule-all.yaml

  # Run kubectl wait to check if the reviews app is deployed and available
  kubectl wait deployments.apps -n default reviews-v1 --for condition=available --timeout=600s
  echo "Sample application deployment complete"
}

# Deploy a virtual service for reviews
function deploy_reviews_vs {
  kubectl --context=${WORKLOAD_CLUSTER} apply -f manifests/virtualservice-reviews.yaml
}

# Annotate the istio-ingressgateway service to use an internal load balancer
function annotate_to_use_ilb {
  kubectl --context=${WORKLOAD_CLUSTER} annotate svc istio-ingressgateway -n istio-system cloud.google.com/load-balancer-type="Internal" --overwrite
  echo "Continuing in 30 seconds. Ctrl+C to cancel"
  sleep 30
  # Get the IP of the internal load balancer created
  NETWORKLB=$(kubectl --context=${WORKLOAD_CLUSTER} get services/istio-ingressgateway -n istio-system \
  --output=jsonpath='{.status.loadBalancer.ingress[0].ip }')
  echo "The IP of the internal LoadBalancer is ${NETWORKLB}"
}

function install_certmanager {
  echo "👩🏽‍💼 Installing Cert Manager"
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.yaml
}

function deploy_reviews_proxy() {
  echo "🦄 Deploy Sample Proxy"

  NETWORKLB=$(kubectl --context=${CLUSTER_NAME} get services/istio-ingressgateway -n istio-system \
    --output=jsonpath='{.status.loadBalancer.ingress[0].ip }')

  sed -i "" "s/@TargetURL@/$NETWORKLB/" apigee-hybrid/reviews-v1/apiproxy/targets/default.xml
  (cd apigee-hybrid/reviews-v1 && zip -r apiproxy.zip apiproxy/*)
  sed -i "" "s/$NETWORKLB/@TargetURL@/" apigee-hybrid/reviews-v1/apiproxy/targets/default.xml

  curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/apis?action=import&name=reviews-v1&validate=true" \
    -H "Authorization: Bearer $(token)" \
    -H "Content-Type: multipart/form-data" \
    -F "zipFile=@apigee-hybrid/reviews-v1/apiproxy.zip"

  PROXY_REV=$(curl -X POST \
     "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/apis?action=import&name=reviews-v1&validate=true" \
     -H "Authorization: Bearer $(token)" \
     -H "Content-Type: multipart/form-data" \
     -F "zipFile=@apigee-hybrid/reviews-v1/apiproxy.zip" | grep '"revision": "[^"]*' | cut -d'"' -f4)

  rm apigee-hybrid/reviews-v1/apiproxy.zip

   curl -v -X POST \
     "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/environments/$ENV_NAME/apis/reviews-v1/revisions/${PROXY_REV}/deployments?override=true" \
     -H "Authorization: Bearer $(token)"

  echo "✅ Sample Proxy Deployed"

  echo "🤓 Try without DNS (first deployment takes a few seconds. Relax and breathe!):"
  echo "curl --cacert $QUICKSTART_ROOT/hybrid-files/certs/$DNS_NAME.crt --resolve api.$DNS_NAME:443:$INGRESS_IP https://api.$DNS_NAME/reviews/1"

  echo "👋 To reach it via the FQDN: Make sure you add this as an NS record for $DNS_NAME: $NAME_SERVER"
}

function run_apigee {
  curl https://raw.githubusercontent.com/apigee/devrel/main/tools/hybrid-quickstart/hybrid13/steps.sh -o /tmp/apigee-hybrid-quickstart-steps.sh
  source /tmp/apigee-hybrid-quickstart-steps.sh

  export CLUSTER_NAME=${APIGEE_RUNTIME_CLUSTER:='apigee-hybrid'}
  export REGION=${APIGEE_RUNTIME_REGION:='europe-west1'}
  export ZONE=${APIGEE_RUNTIME_ZONE:='europe-west1-b'}

  enable_all_apis
  set_config_params

  gcloud container clusters get-credentials ${APIGEE_RUNTIME_CLUSTER} --zone $ZONE --project ${PROJECT_ID}
  kubectl config rename-context gke_${PROJECT_ID}_${ZONE}_${APIGEE_RUNTIME_CLUSTER} ${APIGEE_RUNTIME_CLUSTER}
  kubectl config use-context ${APIGEE_RUNTIME_CLUSTER}

  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole cluster-admin --user "$(gcloud config get-value account)"

  install_certmanager # defined in this file, not the remote steps.sh file

  create_apigee_org
  create_apigee_env "test"
  create_apigee_envgroup "default"
  add_env_to_envgroup "test" "default"
  configure_network

  download_apigee_ctl
  prepare_resources
  create_sa
  install_runtime
  deploy_reviews_proxy # defined in this file, not the remote steps.sh file
}

function run_all {
  set_up_credentials
  enforce_sidecar_injection
  enforce_mtls_in_namespace
  deploy_sample_app
  deploy_reviews_vs
  annotate_to_use_ilb
  run_apigee
  echo "Done running"
}

run_all
