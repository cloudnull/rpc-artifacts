#!/usr/bin/env bash
# Copyright 2014-2017 , Rackspace US, Inc.
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

## Vars ----------------------------------------------------------------------

# OSA SHA
export OSA_RELEASE=${OSA_RELEASE:-"f7f555acb4e299447f47d42c42929541f60e3ad7"}

# Set artifact inventory options
export REPO_HOST=${REPO_HOST:-localhost}
export REPO_USER=${REPO_USER:-root}
export REPO_KEYFILE=${REPO_KEYFILE:-false}

# Gating
export BUILD_TAG=${BUILD_TAG:-}
export INFLUX_IP=${INFLUX_IP:-}
export INFLUX_PORT=${INFLUX_PORT:-"8086"}

# Other
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_OA=${DEPLOY_OA:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TELEGRAF=${DEPLOY_TELEGRAF:-"no"}
export DEPLOY_INFLUX=${DEPLOY_INFLUX:-"no"}
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_UPGRADE_TOOLS=${DEPLOY_UPGRADE_TOOLS:-"no"}
export DEPLOY_RALLY=${DEPLOY_RALLY:-"no"}
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
export DEPLOY_HARDENING=${DEPLOY_HARDENING:-"yes"}
export DEPLOY_RPC=${DEPLOY_RPC:-"yes"}
export DEPLOY_ARA=${DEPLOY_ARA:-"no"}
export DEPLOY_ARTIFACTING=${DEPLOY_ARTIFACTING:-"yes"}
export DEPLOY_SUPPORT_ROLE=${DEPLOY_SUPPORT_ROLE:-"no"}
export DEPLOY_IRONIC=${DEPLOY_IRONIC:-"no"}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
export UNAUTHENTICATED_APT=${UNAUTHENTICATED_APT:-no}

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export OA_DIR="/opt/openstack-ansible"
export OA_OVERRIDES='/etc/openstack_deploy/user_osa_variables_overrides.yml'
export RPCD_DIR="${BASE_DIR}"
export RPCD_OVERRIDES='/etc/openstack_deploy/user_rpco_variables_overrides.yml'
export RPCD_SECRETS='/etc/openstack_deploy/user_rpco_secrets.yml'

export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-''}

export HOST_SOURCES_REWRITE=${HOST_SOURCES_REWRITE:-"yes"}
export HOST_UBUNTU_REPO=${HOST_UBUNTU_REPO:-"http://mirror.rackspace.com/ubuntu"}
export HOST_RCBOPS_REPO=${HOST_RCBOPS_REPO:-"http://rpc-repo.rackspace.com"}

# NOTE(cloudnull): Legacy path is being used here, Change this when this repo
#                  is gated independently.
export SCRIPT_PATH="${SCRIPT_PATH:-${BASE_DIR}/scripts/artifacts-building}"

# Derive the rpc_release version from the group vars
# NOTE(cloudnull): Assume the scripts path is in the process directorie
#                  otherwise fallback to the legacy path.
export RPC_RELEASE="$(${SCRIPT_PATH}/../derive-artifact-version.py || ${SCRIPT_PATH}/derive-artifact-version.py)"

# Read the OS information
for rc_file in openstack-release os-release lsb-release redhat-release; do
  if [[ -f "/etc/${rc_file}" ]]; then
    source "/etc/${rc_file}"
  fi
done

## Functions -----------------------------------------------------------------

# Cater for the use of the FORKS env var for backwards compatibility (Newton
#  and older). It should be removed in Pike.
if [ -n "${FORKS+set}" ]; then
  export ANSIBLE_FORKS=${FORKS}
fi

# The default SSHD configuration has MaxSessions = 10. If a deployer changes
#  their SSHD config, then the ANSIBLE_FORKS may be set to a higher number. We
#  set the value to 10 or the number of CPU's, whichever is less. This is to
#  balance between performance gains from the higher number, and CPU
#  consumption. If ANSIBLE_FORKS is already set to a value, then we leave it
#  alone.
#  ref: https://bugs.launchpad.net/openstack-ansible/+bug/1479812
if [ -z "${ANSIBLE_FORKS:-}" ]; then
  CPU_NUM=$(grep -c ^processor /proc/cpuinfo)
  if [ ${CPU_NUM} -lt "10" ]; then
    export ANSIBLE_FORKS=${CPU_NUM}
  else
    export ANSIBLE_FORKS=10
  fi
fi

function run_ansible {
  openstack-ansible ${ANSIBLE_PARAMETERS} $@
}

function apt_artifacts_available {
  [[ "${DEPLOY_ARTIFACTING}" != "yes" ]] && return 1

  CHECK_URL="${HOST_RCBOPS_REPO}/apt-mirror/integrated/dists/${RPC_RELEASE}-${DISTRIB_CODENAME}"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function git_artifacts_available {
  [[ "${DEPLOY_ARTIFACTING}" != "yes" ]] && return 1

  CHECK_URL="${HOST_RCBOPS_REPO}/git-archives/${RPC_RELEASE}/requirements.checksum"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function python_artifacts_available {
  [[ "${DEPLOY_ARTIFACTING}" != "yes" ]] && return 1

  ARCH=$(uname -p)
  CHECK_URL="${HOST_RCBOPS_REPO}/os-releases/${RPC_RELEASE}/${ID}-${VERSION_ID}-${ARCH}/MANIFEST.in"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function container_artifacts_available {
  [[ "${DEPLOY_ARTIFACTING}" != "yes" ]] && return 1

  CHECK_URL="${HOST_RCBOPS_REPO}/meta/1.0/index-system"

  if curl --silent --fail ${CHECK_URL} | grep "^${ID};${DISTRIB_CODENAME};.*${RPC_RELEASE};" > /dev/null; then
    return 0
  else
    return 1
  fi

}

function configure_apt_sources {

  # Replace the existing apt sources with the artifacted sources.

  sed -i '/^deb-src /d' /etc/apt/sources.list
  sed -i '/-backports /d' /etc/apt/sources.list
  sed -i '/-security /d' /etc/apt/sources.list
  sed -i '/-updates /d' /etc/apt/sources.list

  # Add the RPC-O apt repo source
  echo "deb ${HOST_RCBOPS_REPO}/apt-mirror/integrated/ ${RPC_RELEASE}-${DISTRIB_CODENAME} main" \
    > /etc/apt/sources.list.d/rpco.list

  # Install the RPC-O apt repo key
  curl --silent --fail ${HOST_RCBOPS_REPO}/apt-mirror/rcbops-release-signing-key.asc | apt-key add -

}

function safe_to_replace_artifacts {

  # This function is used by the artifact pipeline to determine whether it
  # is safe to rebuild artifacts for the current head of the mainline branch.
  # It is only ever safe when the mainline and rc branches are different
  # versions or if there is no rc branch. When this is the case, the function
  # will return 0.

  rc_branch="master-rc"

  if git show origin/${rc_branch} &>/dev/null; then
    rc_branch_version="$(git show origin/${rc_branch}:group_vars/all/release.yml \
                         | awk '/rpc_release/{print $2}' | tr -d '"')"
    if [[ "${rc_branch_version}" == "${RPC_RELEASE}" ]]; then
      return 1
    else
      return 0
    fi
  else
    return 0
  fi
}
