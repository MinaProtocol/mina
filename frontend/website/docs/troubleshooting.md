# Troubleshooting

Here are some common problems you might encounter while trying to set up the Coda daemon. If you can't find your issue here please ask for help on [Discord](https://bit.ly/CodaDiscord) or open an issue on [Github](https://github.com/CodaProtocol/coda/issues/new).

## Port forwarding

If you're running a Coda node on a home or office machine, you'll have to set up [port forwarding](https://en.wikipedia.org/wiki/Port_forwarding) to make your node visible on the internet to other Coda nodes. Note that when running Coda in the cloud, this is unnecessary -- instead you should configure security groups for your cloud provider.

### Using UPnP

Follow the steps below to use [MiniUPnP](https://github.com/miniupnp/miniupnp) to forward ports on your router:

1. Run `ifconfig` to get your internal IP address -- you can find this in the output corresponding to the network interface `en0` on macOS. On Linux, this might be on `wlan0`, but oftentimes it is on another network interface - simply look for the one with `inet <IP-address>`. The response will look like this:

        $ ifconfig
        ...
        en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
                ether 8c:85:90:c9:a2:01 
                inet6 fe80::1458:bdd4:e7dc:518e%en0 prefixlen 64 secured scopeid 0x8 
                inet 192.168.101.7 netmask 0xffffff00 broadcast 192.168.101.255
                nd6 options=201<PERFORMNUD,DAD>
                media: autoselect
                status: active
        ...

2. Run the following commands, with the IP address next to `inet` in the previous step. Note that you'll have to run it twice for the two ports below:

        $ sudo upnpc -a <your-ip-address> 8302 8302 TCP
        $ sudo upnpc -a <your-ip-address> 8303 8303 UDP

If these commands succeed, you'll see responses indicating that the ports have been successfully redirected:

```
...
InternalIP:Port = 192.168.101.7:8302
external 148.64.99.117:8302 TCP is redirected to internal 192.168.101.7:8302 (duration=0)
...
InternalIP:Port = 192.168.101.7:8303
external 148.64.99.117:8303 UDP is redirected to internal 192.168.101.7:8303 (duration=0)
```

If you are on a shared network (like an office wireless network), you may get the following error if someone else on the same network has already redirected these ports:

```
AddPortMapping(8302, 8302, 192.168.101.7) failed with code 718 (ConflictInMappingEntry)
```

If this happens, you can forward different ports, as long as they are unused by another application. Two things the keep in mind if you forward custom ports:

- The UDP port forwarded has to be the next consecutive port from the TCP mapping.
- When running Coda daemon commands in the next step, you'll need to add the flag `-external-port <custom-TCP-port>` passing in the TCP port forwarded.

### Manual port forwarding

Depending on your router, you may see one of the following errors:

- `No IGD UPnP Device found on the network!`
- `connect: Connection refused`

If so, find your router model and search for `<model> port forwarding` and follow the instructions to forward the ports from your router to your device running the Coda node. You'll need to open the TCP port 8302, and the UDP port 8303 by default.

## macOS Hostname

If you're running Coda on macOS and see the following time out error `monitor.ml.Error "Timed out getting connection from process"`, you'll need to add your hostname to `/etc/hosts` by running the following:

- `$ hostname` to get your hostname
- `$ vim /etc/hosts` to open your hostfile and add the mapping:

```    
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1       localhost
127.0.0.1       <ADD YOUR HOSTNAME HERE>
```

This is necessary because sometimes macOS doesn't resolve your hostname to your local IP address.

## Connectivity Issues

- If the number of peers is 0, there may be an issue with the IP address - make sure you typed in the IP address and port exactly as specified in [Start a Coda node](#start-a-coda-node).
- If sync status is `Bootstrap`, you'll need to wait for a bit for your node to catch up to the rest of the network. In the Coda network, we do not have to download full transaction history from the genesis block, but nodes participating in block production and compression need to download recent history and the current account data in the network. Future versions of the client will allow non-operating nodes to avoid having to download this data.
- If sync status is `Offline` or `Bootstrap` for more than 15 minutes, you may need to [configure port forwarding for your router](/docs/getting-started/#port-forwarding). Otherwise you may need to resolve connectivity issues with your home network.

## Other issues

### Accepting incoming connections
If you see one or more warnings like the below, then choose "Allow":
```
Do you want the application "coda" to accept incoming network connections?
```

### Failure on daemon restart
If you restart the Coda daemon and it fails, then try deleting your `~/.coda-config` directory and starting it again.

### Daemon restart on computer sleep
If the machine running your Coda node enters sleep mode or hibernates, you will need to restart the Coda daemon once the machine becomes active.
