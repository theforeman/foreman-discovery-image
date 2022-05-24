# mirrorlist.centos.org not available on the CentOS CI
#url --mirrorlist=http://mirrorlist.centos.org/?release=8&arch=$basearch&repo=baseos
#repo --name="AppStream" --mirrorlist=http://mirrorlist.centos.org/?release=8&arch=$basearch&repo=appstream
url --url http://mirror.centos.org/centos/8-stream/BaseOS/$basearch/os/
repo --name="AppStream" --baseurl=http://mirror.centos.org/centos/8-stream/AppStream/$basearch/os/
repo --name="foreman-el8" --baseurl=http://yum.theforeman.org/releases/nightly/el8/$basearch/
repo --name="foreman-plugins-el8" --baseurl=http://yum.theforeman.org/plugins/nightly/el8/$basearch/
module --name=ruby --stream=2.7
module --name=postgresql --stream=12
module --name=foreman --stream=el8
