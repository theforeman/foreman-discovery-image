url --url https://mirror.stream.centos.org/9-stream/BaseOS/$basearch/os/
repo --name="AppStream" --baseurl=https://mirror.stream.centos.org/9-stream/AppStream/$basearch/os/
repo --name="foreman-el9" --baseurl=http://yum.theforeman.org/releases/nightly/el9/$basearch/
repo --name="foreman-plugins-el9" --baseurl=http://yum.theforeman.org/plugins/nightly/el9/$basearch/

