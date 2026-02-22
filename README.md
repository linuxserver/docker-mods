# Mullvad - Docker mod for Wireguard

This mod adds a script which runs on service startup to communicate with the Mullvad APIs. This obtains the relevant config for a chosen Wireguard node which the container can tunnel through when running in CLIENT mode.

## Parameters

### `-e MULLVAD_ACCOUNT` (required)

Your Mullvad account number. This is used to make an API call to obtain your tunnel IP address.

### `-e MULLVAD_PRIVATE_KEY` (required)

The private key of a device on your Mullvad account. You will need to [create a device](https://mullvad.net/en/account/devices) under your account, then use the generated private key for this variable's value. If you have an existing device, you will need to get the private key out of a previously generated config file.

### `-e MULLVAD_LOCATION` (required)

Your spefied location you wish to tunnel through. This variable supports three different formats which effect which node you tunnel through:

| Type | Example | Result |
| :-- | :-- | :-- |
| Region | gb | A node will be randomly picked from all locations within Great Britain |
| City | gb-lon | A node will be randomly picked from one of the locations in London |
| Node(s) | gb-lon-wg-001,gb-lon-wg-002 | Allows for a specific node to be selected, or from a pool of hand-picked nodes. This option is not region or city locked, so you may pick nodes from any global location |

**Note**: The API this script uses does not distinguish between owned or rentded nodes. If that is something you care about, you may need to look at the [Mullvad server list](https://mullvad.net/en/servers) and pick some nodes you wish to tunnel through.

### `-e MULLVAD_DNS` (default: 10.64.0.1)

An optional variable which lets you override the default DNS used for tunnelled connections. If not set, this default's to Mullvad's DNS.

### `-e LAN_NETWORKS`

If you run web services through a Wireguard container (via `network_mode: service`) you will likely lose access to their web UIs due to the container's default routing rules. Use this variable to inform the container to apply a rule which allows inbound traffic from one or more LAN networks. 

E.g. `-e LAN_NETWORKS=192.168.0.0/24,10.20.0.0/16`.

Only use this if you require access to a service's web UI.

### `-e ALLOW_ATTACHED_NETWORKS` (default: false)

If you have a service running within the same stack as Wireguard but not routed through it, you can't be default contact another service routed through the Wireguard container. When this parameter is set to `true`, the script will apply a rule which allows inbound traffic from services on any networks which have been attached to the Wireguard container.