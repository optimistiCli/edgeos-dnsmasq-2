#!/bin/sh

# Run second dnsmasq on EdgeRouter
#
# DISCLAIMER
# You can use this script in any manner that suits you though remember at all 
# times that by using it you agree that you use it at your own risk and neither 
# I nor anybody else except for yourself is to be held responsible in case 
# anything goes wrong as a result of using this script.
#
# For installation instructions please visit 
# https://github.com/optimistiCli/edgeos-dnsmasq-2


# Whitespace-sepatated list of IP addresses where second dnsmasq will listen
ADDRESSES='192.168.1.2 192.168.2.2'

# DNS servers dnsmasq should forward, whitespace-sepatated list of IP addresses
SERVERS='8.8.8.8 8.8.4.4'

# Defaults to /var/log/<script name>.log
# LOG_FILE=/var/log/dnsmasq-2.log

# Defaults to /var/run/dnsmasq/<script name>.pid
# PID_FILE=/var/run/dnsmasq/dnsmasq-2.pid

# Defaults to /tmp/<script name>.conf
# CONFIG_FILE=/tmp/dnsmasq-2.conf


# DO NOT EDIT BEYOND THIS LINE ---+
#                                 |
#             +-------------------+
#             |
#             V
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#


# Add stuff to PATH
PATH='/bin:/usr/bin:/usr/sbin:'"$PATH"
export PATH


# Set up error reporting
function brag_and_exit {
	if [ -n "$1" ] ; then
		ERR_MESSAGE="$1"
	else
		ERR_MESSAGE='Something went terribly wrong'
	fi

	if logger1 -V >>/dev/null 2>&1 ; then 
		# Use logger like a grown-up
		logger -t "${0##*/}" -- $ERR_MESSAGE
	else 
		# Brag to STDERR and hope someone hears
		echo 'Error: '"$ERR_MESSAGE" >&2
	fi

	exit 1
}


# Check dependencies - and yeah, I assume the busybox took care of all the very basic utils
which which >>/dev/null 2>&1 || brag_and_exit 'This system doesnt even have a which. Exiting in disgust!'

for D in realpath id dnsmasq ps kill ; do 
	which "$D" >>/dev/null 2>&1 || brag_and_exit "Can't find prerequisite \"${D}\" in the PATH: $PATH"
done


# Check if run as root
[ "$(id -u)" = "0" ] || brag_and_exit 'This noble script should be run as root, not as some "'$(id -un)'"'


# And your name is?
SCRIPT_REAL_PATH=$(realpath "$0")

SCRIPT_NAME=${0##*/}
SCRIPT_NAME=${SCRIPT_NAME%.*}

echo "$SCRIPT_NAME" | grep -q '^dnsmasq-[[:digit:]]\+$' || brag_and_exit 'This script should be named "dnsmasq-2", "dnsmasq-3" etc'


# Check params
[ -n "$ADDRESSES" ] || brag_and_exit 'No listening addresses specified'
[ -n "$SERVERS" ] || brag_and_exit 'No server to forvard specified'


# Set paths to important stuff
[ -n "$LOG_FILE" ] || LOG_FILE='/var/log/'"$SCRIPT_NAME"'.log'
[ -n "$PID_FILE" ] || PID_FILE='/var/run/dnsmasq/'"$SCRIPT_NAME"'.pid'
[ -n "$CONFIG_FILE" ] || CONFIG_FILE='/tmp/'"$SCRIPT_NAME"'.conf'


# Check if there's a stale second dnsmasq and kill it ruthlessly
if [ -f "$PID_FILE" ] ; then  
	kill $(cat "$PID_FILE")
	sleep 3
fi


# Cook config
ADDRESSES_BUFFER=''
for IP in $ADDRESSES ; do
	ADDRESSES_BUFFER="$ADDRESSES_BUFFER"$'listen-address='"$IP"$'\n'
done

SERVERS_BUFFER=''
for IP in $SERVERS ; do
	SERVERS_BUFFER="$SERVERS_BUFFER"$'server='"$IP"$'\n'
done

cat >"$CONFIG_FILE" <<EO_CONFIG
# This is a custom dnsmasq config autogenerated by $SCRIPT_REAL_PATH

# Listening addresses
$ADDRESSES_BUFFER
# Forwareded servers
$SERVERS_BUFFER
log-facility=$LOG_FILE
pid-file=$PID_FILE
user=dnsmasq
no-resolv
bind-interfaces
EO_CONFIG

dnsmasq -C "$CONFIG_FILE"

