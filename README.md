# RPC-OpenStack

Rackspace Private Cloud (RPC-OpenStack)

----

### OpenStack-Ansible integration

This repository installs
[openstack-ansible](https://github.com/openstack/openstack-ansible)
and provides for additional RPC-OpenStack value-added software.

#### Quick Start with an RPC-OpenStack All-In-One(AIO)

Clone the RPC-OpenStack repository:

``` shell
git clone https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
```

Run the ``deploy.sh`` script. It is recommended to run this script in either
a tmux or screen session. It will take about 90 minutes to complete:

``` shell
cd /opt/rpc-openstack
DEPLOY_AIO=true OSA_RELEASE="stable/pike" ./scripts/deploy.sh
```

#### Basic Overview (non-AIO deployments):

Clone the RPC-OpenStack repository:

``` shell
git clone https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
```

Run the deploy.sh script to perform a basic Installation.

``` shell
cd /opt/rpc-openstack
OSA_RELEASE="stable/pike" ./scripts/deploy.sh
```

To configure the installation please refer to the upstream OpenStack-Ansible
documentation regarding basic [system setup](https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/configure.html).

Once the deploy configuration has been completed please refer to the
OpenStack-Ansible documentation regarding [running the playbooks](https://docs.openstack.org/project-deploy-guide/openstack-ansible/pike/run-playbooks.html).

Upon completion of the deployment run the `playbooks/site.yml` playbook to apply
the RPC-OpenStack value added services.

### Gating

Please see the documentation in [rpc-gating/README.md](https://github.com/rcbops/rpc-gating/blob/master/README.md)

### Testing

Please see [Testing](Testing.md) for an overview of RPC-OpenStack testing.
