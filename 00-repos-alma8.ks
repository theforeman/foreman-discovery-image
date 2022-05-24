# Alma 8 Repos
url --url http://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/
repo --name="AppStream" --baseurl=http://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/
repo --name="foreman-el8" --baseurl=http://yum.theforeman.org/releases/nightly/el8/$basearch/
repo --name="foreman-plugins-el8" --baseurl=http://yum.theforeman.org/plugins/nightly/el8/$basearch/
module --name=ruby --stream=2.7
