repo --name=centos --mirrorlist=http://mirrorlist.centos.org/?release=7&arch=$basearch&repo=os
repo --name=centos-updates --mirrorlist=http://mirrorlist.centos.org/?release=7&arch=$basearch&repo=updates
repo --name=epel7 --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=$basearch
repo --name=foreman-el7 --baseurl=http://yum.theforeman.org/nightly/el7/$basearch/
repo --name=foreman-plugins-el7 --baseurl=http://yum.theforeman.org/plugins/nightly/el7/$basearch/
repo --name=wip-epel7-udpcast --baseurl=https://copr-be.cloud.fedoraproject.org/results/lzap/udp-cast-epel7/epel-7-$basearch/
