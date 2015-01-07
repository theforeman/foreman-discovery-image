# /etc/profile.d/discovery.sh - shell extensions for discovery

# Parse the systemd EnvironmentFile(s) and export the values for use
# in normal shells

filename="/etc/default/discovery"
while read -r line
do
    if [[ $line =~ ^# ]] ; then
        continue
    elif [[ $line =~ .*=.* ]] ; then
	export $line
    else
        continue
    fi
done < "$filename"

filename="/etc/default/discovery-zip-server"
while read -r line
do
    if [[ $line =~ ^# ]] ; then
        continue
    elif [[ $line =~ .*=.* ]] ; then
	export $line
    else
        continue
    fi
done < "$filename"
