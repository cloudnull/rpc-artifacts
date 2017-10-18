#!/usr/bin/env bash
#
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
export DEPLOY_MAAS=${DEPLOY_MAAS:-false}
export DEPLOY_TELEGRAF=${DEPLOY_TELEGRAF:-false}
export DEPLOY_INFLUX=${DEPLOY_INFLUX:-false}
export BUILD_TAG="${BUILD_TAG:-testing}"

## To send data to the influxdb server, we need to deploy and configure
##  telegraf. By default, telegraf will use log_hosts (rsyslog hosts) to
##  define its influxdb servers. These playbooks need maas-get to have run
##  previously.

## Set the following variables when when deploying maas with influx to log
##  to our upstream influx server.
#    INFLUX_PORT
#    INFLUX_IP

## Functions -----------------------------------------------------------------

## Main ----------------------------------------------------------------------

# begin the RPC installation
pushd "$(readlink -f $(dirname ${0})/playbooks)"

  # Deploy and configure the ELK stack
  openstack-ansible setup-logging.yml

  # Get MaaS
  openstack-ansible get-maas.yml

  pushd /opt/rpc-maas/playbooks
    # Deploy and configure RAX MaaS
    if [ "${DEPLOY_MAAS}" != false ]; then
      # Run the rpc-maas setup process
      run_ansible setup-maas.yml

      # verify RAX MaaS is running after all necessary
      # playbooks have been run
      run_ansible verify-maas.yml
    fi

    if [ "${DEPLOY_TELEGRAF}" != false ]; then
      # Set the rpc_maas vars.
      if [[ ! -f "/etc/openstack_deploy/user_rpco_maas_variables.yml" ]]; then
        envsubst < \
          /etc/openstack_deploy/user_rpco_maas_variables.yml.example > \
          /etc/openstack_deploy/user_rpco_maas_variables.yml
      fi

      # If influx port and IP are set enable the variable
      if [[ -n "${INFLUX_PORT}" ]] && [[ -n "${INFLUX_IP}" ]]; then
        sed -i 's|^# influx_telegraf_targets|influx_telegraf_targets|g' /etc/openstack_deploy/user_rpc_maas_variables.yml
      fi
      openstack-ansible maas-tigkstack-telegraf.yml
    fi

    # Deploy Influx
    if [ "${DEPLOY_INFLUX}" != false ]; then
        # We'll assume the deployer has configured his environment
        # to define the influx_all servers.
        openstack-ansible maas-tigkstack-influxdb.yml
    fi
  popd
popd
