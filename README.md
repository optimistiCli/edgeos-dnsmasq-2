# Run second dnsmasq on EdgeRouter
- [Disclaimer](#disclaimer)
- [Why would anyone need a second one?](#why-would-anyone-need-a-second-one)
- [Preparing the router](#preparing-the-router)
  - [Network layout](#network-layout)
  - [Address for the new name server](#address-for-the-new-name-server)
  - [Reconfiguring the "first" dnsmasq](#reconfiguring-the-first-dnsmasq)
- [Installing the second dnsmasq script](#installing-the-second-dnsmasq-script)
  - [Configuration](#configuration)
  - [Installation](#installation)
  - [Running](#running)
- [Peculiarities](#peculiarities)
  - [Compatibility](#compatibility)
  - [Restarting second dnsmasq](#restarting-second-dnsmasq)
  - [More instances and naming](#more-instances-and-naming)
  
## Disclaimer
You can use this script in any manner that suits you though remember at all
times that by using it you agree that you use it at your own risk and neither 
I nor anybody else except for yourself is to be held responsible in case 
anything goes wrong as a result of using this script.

## Why would anyone need a second one?
The main job dnsmasq is tasked with by the EdgeOS is forwarding name resolution
requests to an upstream DNS server typically hosted by the ISP. The good thing 
about dnsmasq is that it also can read hosts file on your router. Hence it can 
be configured to resolve names of some of the hosts on your LAN.

Suppose that you need to use an alternative name server on certain hosts of 
your network. Usually you would just set DNS servers on those hosts manually.
Alternatively you could configure the EdgeOS to set alternative DNS on a 
selected host via DHCP by doing something like that:
```
edit service dhcp-server shared-network-name LAN subnet 192.168.1.0/24
edit static-mapping OtherDNS 
set ip-address 192.168.1.23
set mac-address 12:34:56:78:90:AB
set static-mapping-parameters "option domain-name-servers 8.8.8.8, 8.8.4.4;" 
```
But either scenario disables local host name resolution on the client host:
```
$ nslookup
> server
Default server: 192.168.0.1
Address: 192.168.0.1#53
> 192.168.0.123
Server:		192.168.0.1
Address:	192.168.0.1#53

123.0.168.192.in-addr.arpa	name = localserver.
> localserver
Server:		192.168.0.1
Address:	192.168.0.1#53

Name:	localserver
Address: 192.168.0.123
> server 8.8.8.8
Default server: 8.8.8.8
Address: 8.8.8.8#53
> 192.168.0.123
Server:		8.8.8.8
Address:	8.8.8.8#53

** server can't find 123.0.168.192.in-addr.arpa.: NXDOMAIN
> localserver
Server:		8.8.8.8
Address:	8.8.8.8#53

** server can't find localserver: NXDOMAIN
> ^D
```
My solution is to run a second instance of dnsmasq on the EdgeRouter.

## Preparing the router
Before the second dnsmasq can be used the first dnsmasq run by the system, 
needs to be reconfigured.
### Network layout
For the sake of this tutorial let's assume that the EdgeRouter is 
configured in the following manner:
* eth0 is connected to the WAN, has a dynamic IP address and is of little 
interest to us
* eth1 is configured with the address 192.168.0.1 and is connected to a 
local server, a NAS for example
* eth2 is 192.168.1.1 and the rest of wired LAN is routed through it
* eth3 is 192.168.2.1 and serves the wireless clients

The abovementioned local server's hostname is "localserver" and its IP is 
192.168.0.123. Also there's a workstation on the LAN that needs to use 8.8.8.8 
and 8.8.4.4 for DNS resolution, it's name is "OtherDNS", its NIC's MAC-address 
is 12:34:56:78:90:AB. Wireless clients also need to use the alternative DNS 
servers, but they are configured manually.
### Address for the new name server
Clients will typically use the router IP to access local DNS server, so in our 
setup the first dnsmasq is expected to listen at 192.168.1.1 and 192.168.2.1.
For the second dnsmasq other addresses must be used therefore we will add them 
to appropriate interfaces on the EdgeRouter. But before doing that please make 
sure that they are available and lie outside the ranges used for dynamic 
allocation by the dhcpd:
```
show interfaces ethernet eth2 address 
 address 192.168.1.1/24
show service dhcp-server shared-network-name LAN subnet 192.168.1.0/24  start
 start 192.168.1.128 {
     stop 192.168.1.254
 }
show interfaces ethernet eth3 address 
 address 192.168.2.1/24
show service dhcp-server shared-network-name WiFi subnet 192.168.2.0/24  start
 start 192.168.2.128 {
     stop 192.168.2.254
 }
```
Now, when we know the available IP addresses range we can proceed to configure 
the extra IPs for the second dnsmasq: 
```
edit interfaces ethernet eth2
set address 192.168.1.2/24
top
edit interfaces ethernet eth3
set address 192.168.2.2/24
commit
save
```
### Reconfiguring the "first" dnsmasq
Originally the first dnsmasq would probably be set up something like this:
```
top
edit service dns forwarding
show
 cache-size 150
 dhcp eth0
 listen-on eth1
 listen-on eth2
 listen-on eth3
```
Now the first dnsmasq should be reconfigured to accommodate for the second one.
By default dnsmasq listens on all addresses of all interfaces and then answers 
only select requests. To prevent that behavior "bind-interfaces" option should 
specified:
```
set options bind-interfaces
```
Then the first dnsmasq can be configured to listen on specific addresses:
```
set options listen-address=192.168.1.1
set options listen-address=192.168.2.1
```
And at last it should be stopped from listening on the LAN and WiFi interfaces:
```
delete listen-on eth2
delete listen-on eth3
commit
save
```
_**Important:** the configuration utility will not allow you to remove all 
"listen-on" lines, commit will fail then. Which means that if you want the 
second dnsmasq to be accessible on all the interfaces where the first 
dnsmasq operates, you can probably employ a workaround: create an extra 
virtual interface and point the first dnsmasq at it with a "listen-on" 
directive._

Now the first dnsmasq settings should be something like this:
```
show
 cache-size 150
 dhcp eth0
 listen-on eth1
 options listen-address=192.168.1.1
 options listen-address=192.168.2.1
 options bind-interfaces
```
## Installing the second dnsmasq script
Download or clone the script from the [github repository](https://github.com/optimistiCli/edgeos-dnsmasq-2), 
extract it from the archive if needed.
### Configuration
The second dnsmasq parameters are embedded into the script itself, so to set it 
up you will need to edit the script itself. Please make sure that you are using 
a sane text editor.

First you need to set addresses where the second dnsmasq will be listening 
please edit the "ADDRESSES" line. In this tutorial it should look like this:
```
ADDRESSES='192.168.1.2 192.168.2.2'
```
The other line that needs editing is "SERVERS". It must contain IP addresses of 
the alternative DNS servers. Second dnsmasq will forward requests to either of
these servers:
```
SERVERS='8.8.8.8 8.8.4.4'
```
If the clients need to be configured as members of a domain then the following 
line should be edited accordingly. Otherwise if there is no local search domain 
then this line should be commented out altogether.
```
DOMAIN_NAME='mydomain.net'
```
The rest of the parameters do not require editing. Please read the comments 
inside the script if you feel like figuring them out.
### Installation
Please copy the edited script to the EdgeRouter. I'd use scp (or WinSCP if I 
was on Windows) to do that. Now in the EdgeOS CLI please exit the "configure" 
console and (optionally) start the "sh" shell:
```
admin@ubnt# exit
exit
vbash-4.1$ sh
sh-4.2$ 
```
You can move the script to the "/config/scripts/post-config.d/" directory where 
it will be run automatically every time the router boots up:
```
sh-4.2$ sudo mv dnsmasq-2.s /config/scripts/post-config.d/
```
Please set the ownership and the permissions of the script file:
```
sh-4.2$ sudo chown root:root /config/scripts/post-config.d/dnsmasq-2.sh
sh-4.2$ sudo chmod 755 /config/scripts/post-config.d/dnsmasq-2.sh
```
The result should look similar to this:
```
sh-4.2$ ls -l /config/scripts/post-config.d/dnsmasq-2.sh 
-rwxr-xr-x    1 root     root          3484 Sep 14  2016 /config/scripts/post-config.d/dnsmasq-2.sh
```
### Running
You can just run the script now:
```
sh-4.2$ sudo /config/scripts/post-config.d/dnsmasq-2.sh
```
Now check out two instances of dnsmasq running peacefully side-by-side:
```
sh-4.2$ ps uax | grep dnsmasq
dnsmasq   3126  0.0  0.3   5072   940 ?        S    12:59   0:00 dnsmasq -C /tmp/dnsmasq-2.conf
dnsmasq   4227  0.0  0.3   5076   948 ?        S    13:31   0:07 /usr/sbin/dnsmasq -x /run/dnsmasq/dnsmasq.pid -u dnsmasq -7 /etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new --local-service
```
And check if the second dnsmasq is working as expected for the client:
```
$ nslookup 
> server 192.168.1.2
Default server: 192.168.1.2
Address: 192.168.1.2#53
> 192.168.0.123
Server:		192.168.1.2
Address:	192.168.1.2#53

123.0.168.192.in-addr.arpa	name = localserver.
> localserver
Server:		192.168.1.2
Address:	192.168.1.2#53

Name:	localserver
Address: 192.168.0.123
> ubnt.com
Server:		192.168.1.2
Address:	192.168.1.2#53

Non-authoritative answer:
Name:	ubnt.com
Address: 52.8.106.33
Name:	ubnt.com
Address: 54.183.101.244
```
## Peculiarities
### Compatibility
This script was tested on EdgeRouter X firmware versions 1.8.5 and 1.9.0. In my 
experience it can survive reboot and software update. Since it has very basic 
requirements I expect it to be compatible with other EdgeOS devices and 
firmware versions, but I cannot be entirely sure.
### Restarting second dnsmasq
To restart the second dnsmasq just run the script. It should work, unless you 
renamed the script or reconfigured the path to the pid file or did something 
similar. 
### More instances and naming
Theoretically speaking you can use this script to run more the 3rd, the 4th and 
so on instances of dnsmasq. I never tested it, but don't see any reason why it 
should not work. Copying dnsmasq-2 to dnsmasq-3, dnsmasq-4 etc and editing 
addresses and servers list in every copy. Please also note that the scrip will 
not run unless it is named according to the convention indicated above.

Enjoy!
