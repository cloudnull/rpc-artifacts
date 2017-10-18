#!/usr/bin/env bash
# Copyright 2014-2017, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Shell Opts ----------------------------------------------------------------
set -e -u -x
set -o pipefail

## Vars ----------------------------------------------------------------------
export DEPLOY_AIO=${DEPLOY_AIO:-false}

## Functions -----------------------------------------------------------------

## Main ----------------------------------------------------------------------

# Run the RPC-O installation process
source "$(readlink -f $(dirname ${0})/install.sh)"

# Setup OpenStack
pushd /opt/openstack-ansible
  if [ "${DEPLOY_AIO}" != false ]; then

    ## SPECIFIC FOR PIKE: "https://review.openstack.org/#/q/I2443242f285381037a0351ceb4e6d997271dbd4b"
    # TODO(cloudnull): Once merged into the PIKE branch remove these lines.
    # NOTE(cloudnull): Install ARA from git sources on a specific checkout.
    mkdir -p /tmp/openstack
    if [[ ! -d "/tmp/openstack/ara" ]]; then
      git clone https://github.com/openstack/ara /tmp/openstack/ara
    fi
    pushd /tmp/openstack/ara
      git checkout "0.14.0"
      # NOTE(cloudnull): ARA does not constrain ansible, so we're constraining.
      sed -i 's|^ansible.*|ansible<=2.3.2.0|g' /tmp/openstack/ara/requirements.txt
    popd
    ## SPECIFIC FOR PIKE

    # Run the AIO job.
    ./scripts/gate-check-commit.sh

    # Deploy RPC-OpenStack.
    source deploy-rpco.sh

  else
    # Generate the scretes required for the deployment.
    python scripts/pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml
    python scripts/pw-token-gen.py --file /etc/openstack_deploy/user_rpco_secrets.yml

    echo -e "\n**System prepared for Installation**
To configure the installation please refer to the upstream OpenStack-Ansible
documentation regarding basic [system setup]
(https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/configure.html).

Once the deploy configuration has been completed please refer to the
OpenStack-Ansible documentation regarding [running the playbooks]
(https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/run-playbooks.html).

Upon completion of the deployment run the `playbooks/site.yml` playbook to apply
the RPC-OpenStack value added services.
"
  fi
popd
