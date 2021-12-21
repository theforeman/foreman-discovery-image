url --mirrorlist=http://mirrorlist.centos.org/?release=8&arch=$basearch&repo=baseos
repo --name="AppStream" --mirrorlist=http://mirrorlist.centos.org/?release=8&arch=$basearch&repo=appstream
repo --name="foreman-el8" --baseurl=http://yum.theforeman.org/releases/nightly/el8/$basearch/
repo --name="foreman-plugins-el8" --baseurl=http://yum.theforeman.org/plugins/nightly/el8/$basearch/
module --name=ruby --stream=2.7
