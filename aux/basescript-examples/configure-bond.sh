no_tui
fact via_script 1
clean_nm
cfg_bond bond0
for DEV in eth0 eth1; do cfg_slave bond0 $DEV; done
reload_nm
sleep 30
discover_now
