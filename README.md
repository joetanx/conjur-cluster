# Conjur Enterprise cluster and followers + Podman + RHEL 9 + Keepalived + Nginx
A guide to setup Conjur Enterprise cluster and followers on Podman on RHEL 9 using:
- Keepalived for cluster floating IP address
- Nginx + Keepalived load balancers for followers

## Lab Environment
### Software Versions

|Software|Version|
|---|---|
|RHEL|9.0|
|Podman|4.0.2|
|Conjur Enterprise|12.6|
|Keepalived|2.2.4|
|Nginx|1.20.1|

### Servers/Networking

|Function|Hostname|IP Address|
|---|---|---|
|Conjur cluster service|conjur.vx|192.168.0.10|
|Conjur leader node|cjr1vx|192.168.0.11|
|Conjur synchronous standby node|cjr2vx|192.168.0.12|
|Conjur asynchronous standby node|cjr3vx|192.168.0.13|
|Conjur follower service|follower.vx|192.168.0.20|
|Conjur follower nodes|flr{1..2}vx|192.168.0.{21..22}|
|Load balancers|lb{1..2}.vx|192.168.0.{31..32}|

# 1.0 Setup host prerequisites and Conjur appliance container on all Conjur nodes
☝️ Perform on **all Conjur nodes**
# 1.1 Setup host prerequisites
- Install Podman
- Upload `conjur-appliance_12.6.0.tar.gz` to the container host: contact your CyberArk representative to acquire the Conjur container image
- Prepare data directories: these directories will be mounted to the Conjur container as volumes
- Setup [Conjur CLI](https://github.com/cyberark/cyberark-conjur-cli): the client tool to interface with Conjur
```console
yum -y install podman
podman load -i conjur-appliance_12.6.0.tar.gz
mkdir -p /opt/conjur/{security,config,backups,seeds,logs}
curl -L -o conjur-cli-rhel-8.tar.gz https://github.com/cyberark/conjur-api-python3/releases/download/v7.1.0/conjur-cli-rhel-8.tar.gz
tar xvf conjur-cli-rhel-8.tar.gz
mv conjur /usr/local/bin/
```
- Clean-up
```console
rm -f conjur-appliance_12.6.0.tar.gz conjur-cli-rhel-8.tar.gz
```

## 1.1.1 Note on SELinux and Container Volumes
- SELinux may prevent the container access to the data directories without the appropriate SELinux labels
- Ref: [podman-run - Labeling Volume Mounts](https://docs.podman.io/en/latest/markdown/podman-run.1.html)
- There are 2 ways to enable container access to the data directories:
  1. Use `semanage fcontext` and `restorecon` to relabel the data directories
    ```console
    yum install -y policycoreutils-python-utils
    semanage fcontext -a -t svirt_sandbox_file_t "/opt/conjur(/.*)?"
    restorecon -R -v /opt/conjur
    ```
  2. Add `:z` or `:Z` to the volume mounts when running the container so that Podman will automatically label the data directories
    - `:z` - indicates that content is shared among multiple container
    - `:Z` - indicates that content is is private and unshared

## 1.2. Run Conjur appliance container
### 1.2.1 Method 1: Running Conjur master on the default bridge network
- Podman run command:
```console
podman run --name conjur -d \
--restart=unless-stopped \
-p "443:443" -p "444:444" -p "5432:5432" -p "1999:1999" \
--log-driver journald \
-v /opt/conjur/config:/etc/conjur/config:Z \
-v /opt/conjur/security:/opt/cyberark/dap/security:Z \
-v /opt/conjur/backups:/opt/conjur/backup:Z \
-v /opt/conjur/seeds:/opt/cyberark/dap/seeds:Z \
-v /opt/conjur/logs:/var/log/conjur:Z \
registry.tld/conjur-appliance:12.6.0
```

### 1.2.2 Method 2: Running Conjur master on the Podman host network
- Podman run command:
```console
podman run --name conjur -d \
--restart=unless-stopped \
--network host \
--log-driver journald \
-v /opt/conjur/config:/etc/conjur/config:Z \
-v /opt/conjur/security:/opt/cyberark/dap/security:Z \
-v /opt/conjur/backups:/opt/conjur/backup:Z \
-v /opt/conjur/seeds:/opt/cyberark/dap/seeds:Z \
-v /opt/conjur/logs:/var/log/conjur:Z \
registry.tld/conjur-appliance:12.6.0
```
- Add firewall rules on the Podman host
```console
firewall-cmd --add-service https --permanent
firewall-cmd --add-service postgresql --permanent
firewall-cmd --add-port 444/tcp --permanent
firewall-cmd --add-port 1999/tcp --permanent
firewall-cmd --reload
```

## 1.3 Configure container to start on boot
- Run the Conjur container as systemd service and configure it to setup with container host
- Ref: <https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman>
```console
podman generate systemd conjur --name --container-prefix="" --separator="" > /etc/systemd/system/conjur.service
systemctl enable conjur
```

# 2.0 Setup Conjur leader node
☝️ Perform on **Conjur leader node**: the leader node is `cjr1.vx` / `192.168.0.11` in this lab environment
## 2.1 Configure Conjure leader
- Edit the admin account password in `-p` option and the Conjur account (`cyberark`) according to your environment
```console
podman exec conjur evoke configure master --accept-eula -h conjur.vx --master-altnames "conjur.vx" -p CyberArk123! cyberark
```

## 2.4 Setup Conjur certificates
### Lab environment certificate chain
- The `conjur-certs.tgz` includes my personal certificate chain for CA, leader and follower, you should generate your own certificates
- Refer to <https://joetanx.github.io/self-signed-ca/> for a guide to generate your own certificates
- ☝️ **Note**: The Common Name of Conjur certificates should be the FQDN of the access endpoint, otherwise errors will occur

|Certificate|Purpose|Common Name|Subject Alternative Names|
|---|---|---|---|
|central.pem|Certificate Authority|Central Authority||
|conjur.pem / conjur.key|Conjur cluster certificate|conjur.vx|cjr1.vx, cjr2.vx, cjr3.vx|
|follower.pem / follower.key|Conjur follower certificate|follower.vx|flr1.vx, flr2.vx|

- ☝️ **Note**: In event of `error: cert already in hash table`, ensure that the Conjur serverfollower certificates do not contain the CA certificate
```console
curl -L -o conjur-certs.tgz https://github.com/joetanx/conjur-cluster/raw/main/conjur-certs.tgz
podman cp conjur-certs.tgz conjur:/opt/cyberark/dap/certificates/
podman exec conjur tar xvf /opt/cyberark/dap/certificates/conjur-certs.tgz -C /opt/cyberark/dap/certificates/
podman exec conjur evoke ca import -fr /opt/cyberark/dap/certificates/central.pem
podman exec conjur evoke ca import -k /opt/cyberark/dap/certificates/conjur.key -s /opt/cyberark/dap/certificates/conjur.pem
podman exec conjur evoke ca import -k /opt/cyberark/dap/certificates/follower.key /opt/cyberark/dap/certificates/follower.pem
podman exec conjur cp /opt/conjur/etc/ssl/follower.vx.pem /opt/conjur/etc/ssl/flr1.vx.pem
podman exec conjur cp /opt/conjur/etc/ssl/follower.vx.key /opt/conjur/etc/ssl/flr1.vx.key
podman exec conjur cp /opt/conjur/etc/ssl/follower.vx.pem /opt/conjur/etc/ssl/flr2.vx.pem
podman exec conjur cp /opt/conjur/etc/ssl/follower.vx.key /opt/conjur/etc/ssl/flr2.vx.key
```
- Clean-up
```console
podman exec conjur rm -rf /opt/cyberark/dap/certificates
rm -f conjur-certs.tgz
```
