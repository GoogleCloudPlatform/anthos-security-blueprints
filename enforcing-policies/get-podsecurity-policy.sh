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

# Copy to local workstation the PodSecurity constraint files from the OPA/gatekeeper library
wget -O privileged-containers.yaml  https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/privileged-containers/constraint.yaml
wget -O apparmor.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/apparmor/constraint.yaml
wget -O capabilities.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/capabilities/constraint.yaml
wget -O flexvolume-drivers.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/flexvolume-drivers/constraint.yaml
wget -O forbidden-sysctls.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/forbidden-sysctls/constraint.yaml
wget -O fsgroup.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/fsgroup/constraint.yaml
wget -O host-filesystem.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/host-filesystem/constraint.yaml
wget -O host-namespaces.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/host-namespaces/constraint.yaml
wget -O host-network-ports.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/host-network-ports/constraint.yaml
wget -O privileged-containers.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/privileged-containers/constraint.yaml
wget -O proc-mount.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/proc-mount/constraint.yaml
wget -O read-only-root-filesystem.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/read-only-root-filesystem/constraint.yaml
wget -O seccomp.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/seccomp/constraint.yaml
wget -O selinux.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/selinux/constraint.yaml
wget -O users.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/users/constraint.yaml
wget -O volumes.yaml https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/library/pod-security-policy/volumes/constraint.yaml

# Add enforcementAction: dryrun to the end of each policy file. To enforce the policy: change enforcementAction from dryrun to deny
echo "enforcementAction: dryrun" >> privileged-containers.yaml
echo "enforcementAction: dryrun" >> apparmor.yaml
echo "enforcementAction: dryrun" >> capabilities.yaml
echo "enforcementAction: dryrun" >> flexvolume-drivers.yaml
echo "enforcementAction: dryrun" >> forbidden-sysctls.yaml
echo "enforcementAction: dryrun" >> fsgroup.yaml
echo "enforcementAction: dryrun" >> host-filesystem.yaml
echo "enforcementAction: dryrun" >> host-namespaces.yaml
echo "enforcementAction: dryrun" >> host-network-ports.yaml
echo "enforcementAction: dryrun" >> privileged-containers.yaml
echo "enforcementAction: dryrun" >> proc-mount.yaml
echo "enforcementAction: dryrun" >> read-only-root-filesystem.yaml
echo "enforcementAction: dryrun" >> seccomp.yaml
echo "enforcementAction: dryrun" >> selinux.yaml
echo "enforcementAction: dryrun" >> users.yaml
echo "enforcementAction: dryrun" >> volumes.yaml
