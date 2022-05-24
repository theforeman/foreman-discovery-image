url --url http://mirror.centos.org/centos/8-stream/BaseOS/$basearch/os/
repo --name="AppStream" --baseurl=http://mirror.centos.org/centos/8-stream/AppStream/$basearch/os/
repo --name="foreman-el8" --baseurl=http://yum.theforeman.org/releases/nightly/el8/$basearch/
repo --name="foreman-plugins-el8" --baseurl=http://yum.theforeman.org/plugins/nightly/el8/$basearch/
module --name=ruby --stream=2.7
