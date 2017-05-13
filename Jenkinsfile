podTemplate(label: 'k8s-ci', containers: [
    containerTemplate(name: 'dind', image: 'docker:dind', privileged: true,
                      args: '--mtu 1400'),
    containerTemplate(name: 'kolla-k8s', image: 'lyanchih/kolla-k8s', ttyEnabled: true,
                      command: 'cat', envVars: [
            containerEnvVar(key: 'KOLLA_CONFIG_DIRECTORY', value: '/data/kolla')
        ]),
    containerTemplate(name: 'lazykube', image: 'lyanchih/lazykube', ttyEnabled: true, privileged: true,
        envVars: [
            containerEnvVar(key: 'DEBIAN_FRONTEND', value: 'noninteractive'),
            containerEnvVar(key: 'DOCKER_HOST', value: '127.0.0.1'),
            containerEnvVar(key: 'LIBVIRT_DEFAULT_URI', value: 'qemu+unix:///system?socket=/var/run/libvirt/libvirt-sock'),
            containerEnvVar(key: 'FIRST_BRIDGE', value: 'vm0'),
            containerEnvVar(key: 'DOCKER_HOST_INTERFACE', value: 'net0')
        ])
    ], volumes: [
        hostPathVolume(hostPath: '/data/.ssh', mountPath: '/home/jenkins/.ssh'),
        hostPathVolume(hostPath: '/var/run/libvirt', mountPath: '/var/run/libvirt'),
        emptyDirVolume(memory: false, mountPath: '/src'),
        emptyDirVolume(memory: false, mountPath: '/home/jenkins/.kube'),
        configMapVolume(mountPath: '/etc/lazykube', configMapName: 'lazykube-conf'),
        configMapVolume(mountPath: '/data/kolla', configMapName: 'kolla-conf'),
    ], nodeSelector: 'ci=k8s') {

    node ('k8s-ci') {

         stage 'Deploy kubernetes'
         container('lazykube') {
             sh 'curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x ./kubectl && cp ./kubectl /usr/bin/kubectl'

             stage 'Waiting for kubectl config'
             sh 'while true; do sleep 5; [ -f ~/.kube/config ] && break || continue; done; echo "k8s config had been created"'

             stage 'Change kubectl config server IP and show config'
             sh 'kubectl config set-cluster k8s --server=https://172.17.20.100 && kubectl config view'

             stage 'Waiting for k8s deploying'
             sh 'while true; do sleep 5; kubectl get pods && break || continue; done'
         }

         stage 'Deploy openstack'
         container('kolla-k8s') {
             sh '/entrypoint.sh prepare'

             sh '/entrypoint.sh deploy'

             sh '/entrypoint.sh test'
         }

         stage 'Destroy k8s cluster'
         container('lazykube') {
             sh 'cd /src/LazyKube && ./scripts/libvirt destroy'
         }
    }
}
