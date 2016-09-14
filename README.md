# Run second dnsmasq on EdgeRouter


## Disclaimer
You can use this script in any manner that suits you though remember at all
times that by using it you agree that you use it at your own risk and neither 
I nor anybody else except for yourself is to be held responsible in case 
anything goes wrong as a result of you using this script.

## Why would anyone need a second one?
The main job dnsmasq is tasked with by the EdgeOS is forwarding name resolution
requests to an upstream DNS server tipically hosted by the ISP. The good thing 
about dnsmasq is that it also can read hosts file on your router. Hence it can 
be configured to resolve names of some of the hosts on your LAN.

Suppose that you need to use an alternative name server on certain hosts of 
your network. Usually you would just set DNS servers on those hosts manually.
Alternatively you could configure the EdgeOS to set alternative DNS on a 
selected host via dhcp by doing something like that:
```
edit service dhcp-server shared-network-name LAN subnet 192.168.1.0/24
edit static-mapping OtherDNS 
set ip-address 192.168.1.23
set mac-address 12:34:56:78:90:AB
set static-mapping-parameters "option domain-name-servers 8.8.8.8, 8.8.4.4;" 
```
But either scenario disables local host name resolution:
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
For the sake of this tutorial let's assume for that the EdgeRouter is 
configured in the following manner:
* eth0 is connected to the WAN, has a dynamic IP address and is of little 
interest to us
* eth1 is configured with the address 192.168.0.1 and is connected to a 
server
* eth2 is 192.168.1.1 and the rest of wired LAN is routed throug it
* eth3 is 192.168.2.1 and serves the wireless clients

The abovementioned local server's hostname is "localserver" and it's IP is 
192.168.0.123. Also there's a workstation on the LAN that needs to use 8.8.8.8 
and 8.8.4.4 for DNS resolution, it's name is "OtherDNS", its NIC's MAC-address 
is 12:34:56:78:90:AB. Wireless clients also need use the second dnsmasq, but 
they are configured manually.
### Address for the new name server
Clients will typically use the router IP to access local DNS server, so in our 
setup the first dnsmasq is expected to listen at 192.168.1.1 and 192.168.2.1.
Other addresses must be used for the second dnsmasq hence we will add them to
appropriate interfaces on the EdgeRouter, but before doing that please make sure 
that they are available and lie outside the ranges used for dynamic allocation 
by the dhcpd. 
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
second dnsmasq to be accessible from all the interfaces where the first 
dnsmasq operates, you probably can create an extra virtual interface just for 
that and use it in the "listen-on" directive._

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
