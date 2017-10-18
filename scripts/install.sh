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
export OSA_RELEASE="${OSA_RELEASE:-master}"

## Functions -----------------------------------------------------------------

## Main ----------------------------------------------------------------------

# If /opt/openstack-ansible exists, delete it if it is not a git clone
if [[ -d "/opt/openstack-ansible" ]] && [[ ! -d "/opt/openstack-ansible/.git" ]]; then
  rm -rf /opt/openstack-ansible
fi

# Git clone the openstack-ansible repository
if [[ ! -d "/opt/openstack-ansible" ]]; then
  git clone https://git.openstack.org/openstack/openstack-ansible /opt/openstack-ansible
fi

pushd "/opt/openstack-ansible"
  # Check if the current SHA does not match the desired SHA
  if [[ "$(git rev-parse HEAD)" != "${OSA_RELEASE}" ]]; then

    # If the SHA we want does not exist in the git repo, update the repo
    if ! git cat-file -e ${OSA_RELEASE} 2> /dev/null; then
      git fetch --all
    fi

    # Now checkout the correct SHA
    git checkout "${OSA_RELEASE}"
  fi

  # Run the regular ansible bootstrap.
  source ./scripts/bootstrap-ansible.sh
popd

# Get RPC Ansible roles.
ansible-playbook /opt/openstack-ansible/tests/get-ansible-role-requirements.yml \
                 -i /opt/openstack-ansible/tests/test-inventory.ini \
                 -e role_file="$(readlink -f $(dirname ${0})/../ansible-role-requirements.yml)" \
                 -vv

# Setup the basic OSA configuration structure.
if [[ ! -d "/etc/openstack_deploy" ]]; then
  cp -Rv /opt/openstack-ansible/etc/opentsack_deploy /etc/opentsack_deploy
fi

if [[ ! -f "etc/openstack_deploy/user_rpco_secrets.yml" ]]; then
  cp etc/openstack_deploy/user_rpco_secrets.yml.example etc/openstack_deploy/user_rpco_secrets.yml
fi

# Sync the RPC-OpenStack variables into place.
rsync -av --exclude '*.bak' "$(readlink -f $(dirname ${0})/../etc/openstack_deploy)/" \
                            /etc/openstack_deploy/
for dir_name in group_vars env.d; do
  if [[ -d "/etc/openstack_deploy/${dir_name}" ]]; then
    chmod ugo+rX "/etc/openstack_deploy/${dir_name}"
  fi
done
