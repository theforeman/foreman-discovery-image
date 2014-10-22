# do not disable updates (facter update needed)
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-19&arch=$basearch
repo --name=fedora-updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f19&arch=$basearch
repo --name=foreman-f19 --baseurl=http://yum.theforeman.org/nightly/f19/$basearch/
