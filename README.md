# Setup Conjur Enterprise cluster on RHEL with Podman + keepalived and nginx load balancer

### Software Versions
- RHEL 9.0
- Podman 4.0.2
- Conjur Enterprise 12.6.0

# 1.0 Setup host prerequisites
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
