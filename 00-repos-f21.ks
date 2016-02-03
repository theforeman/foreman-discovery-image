# do not disable updates (facter update needed)
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-21&arch=$basearch
repo --name=fedora-updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f21&arch=$basearch
repo --name=foreman-f21 --baseurl=http://yum.theforeman.org/nightly/f21/$basearch/
repo --name=foreman-plugins-f21 --baseurl=http://yum.theforeman.org/plugins/nightly/f21/$basearch/
