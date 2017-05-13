#!/bin/bash

set -e

KOLLA_CONFIG_DIRECTORY=${KOLLA_CONFIG_DIRECTORY:=/etc/kolla}
KOLLA_K8S_VALUE=${KOLLA_K8S_VALUE:=value.yaml}
NODE_CONFIG_DIRECTORY=${NODE_CONFIG_DIRECTORY:=/etc/kolla}

if [ -f "$KOLLA_CONFIG_DIRECTORY/$KOLLA_K8S_VALUE" ]; then
    NODE_CONFIG_DIRECTORY="$(crudini --get $KOLLA_CONFIG_DIRECTORY/$KOLLA_K8S_VALUE DEFAULT node_config_directory)"
fi

function usage() {
    cat - <<EOF
$0: COMMAND

commands:
prepare   Prepare deploy environment 
deploy    Deploy openstack by helm
test      Test openstack
EOF
}

function clone_cd_kolla_kubernetes() {
    cd ~
    if [ ! -d 'kolla-kubernetes' ]; then
        git clone http://github.com/openstack/kolla-kubernetes
    fi
    cd kolla-kubernetes
}

function download_kubectl() {
    echo "Finding latest kubectl"
    # curl -s https://github.com/kubernetes/kubernetes/releases/latest  | awk -F '[<>]' '/.*/ { match($0, "tag/([^\"]+)",a); print a[1] }'
    LATEST=$(curl -s https://github.com/kubernetes/kubernetes/releases/latest  | awk -F '[<>]' '/.*/ { print substr($0,match($0, "tag/([^\"]+)")+4,RLENGTH-4);  }' | head -1)
    
    echo "Getting kubectl-$LATEST"
    curl -o /usr/bin/kubectl "http://storage.googleapis.com/kubernetes-release/release/$LATEST/bin/linux/amd64/kubectl"
    chmod 755 /usr/bin/kubectl
}

function prepare() {
    clone_cd_kolla_kubernetes
    
    [ -d "/etc/kolla" ] || mkdir /etc/kolla
    
    if [ ! -f "/etc/kolla/passwords.yml" ]; then
        git clone http://github.com/openstack/kolla-ansible
        cp kolla-ansible/etc/kolla/passwords.yml /etc/kolla/passwords.yml
    fi

    pip install .
    echo "Generate openstack password"
    tools/generate_passwords.py

    echo "Generate openstack service config"
    ansible-playbook -e @/etc/kolla/passwords.yml -e @etc/kolla-kubernetes/kolla-kubernetes.yml $([ -f "$KOLLA_CONFIG_DIRECTORY/$KOLLA_K8S_VALUE" ] && echo "-e @$KOLLA_CONFIG_DIRECTORY/$KOLLA_K8S_VALUE") ansible/site.yml

    sed -i '/innodb_buffer_pool_size = /d' $NODE_CONFIG_DIRECTORY/mariadb/galera.cnf

    echo "Download kubectl"
    download_kubectl

    echo "Show kubectl config"
    kubectl config view

    tools/wait_for_pods.sh kolla

    kubectl create namespace kolla || true
    
    echo "Generate k8s configmap"
    cd $NODE_CONFIG_DIRECTORY
    for l in neutron-{server,{openvswitch,metadata,l3,dhcp}-agent} horizon; do
        ls $l | awk -v l=$l '/_/{printf "%s/%s ", l, $1; gsub("_","-",$1); print l"/"$1}' | xargs -I{} echo mv {} | bash || true
    done

    ls | xargs -I{} kubectl create configmap {} --from-file={} || true
    cd -

    echo "Generate k8s secret"
    sed '/^#/d; /^.*password: .*$/!d; s|_|-|g;s|: | |' /etc/kolla/passwords.yml | awk '{printf "kubectl create secret generic %s --from-literal=password=%s\n",$1,$2}' | bash

    echo "Generate k8s resolv workaround"
    tools/setup-resolv-conf.sh kolla

    echo "Setup helm..."
    sed 's|sudo||' tools/setup_helm.sh | bash

    helm serve > /var/log/helm-serve.log &

    sleep 2

    helm init || true

    tools/helm_build_all.sh ./tmp
}

function deploy() {
    clone_cd_kolla_kubernetes

    tools/wait_for_pods.sh kolla

    if [ -f "$KOLLA_CONFIG_DIRECTORY/nodes" ]; then
        kubectl get nodes
        nodes=$(kubectl get nodes --no-headers | awk '{if ($2!="Ready") print $1}')
        while [ ! -z "$nodes" ]; do
            for n in $nodes; do
                echo "Waiting $n node to ready"
            done
            sleep 5
            nodes=$(kubectl get nodes --no-headers | awk '{if ($2!="Ready") print $1}')
            kubectl get nodes
        done
        awk '{printf "kubectl label node %s %s=true\n",$1,$2}' $KOLLA_CONFIG_DIRECTORY/nodes | bash
    else
        kubectl label node work1 kolla_mariadb=true
        kubectl label node work1 kolla_controller=true
        kubectl label node work2 kolla_compute=true
    fi

    cd helm
    echo "Deploy controller node service"
    for s in mariadb rabbitmq memcached keystone horizon nova-control glance openvswitch neutron cinder-control; do
        echo "Install service $s"
        helm install -f $KOLLA_CONFIG_DIRECTORY/global.yaml service/$s
        sleep 5
    done
    
    while ! ../tools/wait_for_pods.sh kolla; do
        sleep 1
    done

    echo "Deploy compute node service"
    helm install -f $KOLLA_CONFIG_DIRECTORY/global.yaml -f $KOLLA_CONFIG_DIRECTORY/compute.yaml microservice/neutron-openvswitch-agent-daemonset
    for s in openvswitch nova-compute; do
        echo "Install service $s"
        helm install -f $KOLLA_CONFIG_DIRECTORY/global.yaml -f $KOLLA_CONFIG_DIRECTORY/compute.yaml service/$s
        sleep 5
    done

    while ! ../tools/wait_for_pods.sh kolla; do
        sleep 1
    done

    helm install -f $KOLLA_CONFIG_DIRECTORY/global.yaml microservice/nova-cell0-create-db-job
    helm install -f $KOLLA_CONFIG_DIRECTORY/global.yaml microservice/nova-api-create-simple-cell-job

    while ! ../tools/wait_for_pods.sh kolla; do
        sleep 1
    done
}

function test-openstack() {
    clone_cd_kolla_kubernetes

    tools/build_local_admin_keystonerc.sh

    echo "Openstack openrc"
    cat ~/keystonerc_admin
}

CMD=$1

case "$CMD" in
    prepare)
        prepare
        ;;
    deploy)
        deploy
        ;;
    test)
        test-openstack
        ;;
    *)
        usage
        ;;
esac
