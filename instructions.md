# Snowflake Proxy
Snowflake is a system to defeat internet censorship. People who are censored can use Snowflake to access the internet. Their connection goes through Snowflake proxies, which are run by volunteers.

If your internet access is not censored, you should consider running a Snowflake proxy to help users in censored networks. There is no need to worry about which websites people are accessing through your proxy. Their visible browsing IP address will match their Tor exit node, not yours.

## Usage
Snowflake is currently deployed as a pluggable transport for Tor.

## Using Snowflake with Tor
To use the Snowflake client with Tor, you will need to add the appropriate Bridge and ClientTransportPlugin lines to your torrc file. See the client README for more information on building and running the Snowflake client.

## Running a Snowflake Proxy
You can contribute to Snowflake by running a Snowflake proxy. We have the option to run a proxy in your browser or as a standalone Go program. See our [community documentation](https://community.torproject.org/relay/setup/snowflake/) for more details.

## FAQ
**Q: How does it work?**
In the Tor use-case:

1. Volunteers visit websites that host the 'snowflake' proxy, run a snowflake web extension, or use a standalone proxy.
2. Tor clients automatically find available browser proxies via the Broker
(the domain fronted signaling channel).
3. Tor client and browser proxy establish a WebRTC peer connection.
4. Proxy connects to some relay.
5. Tor occurs.

More detailed information about how clients, snowflake proxies, and the Broker
fit together on the way...

**Q: What are the benefits of this PT compared with other PTs?**
Snowflake combines the advantages of flashproxy and meek. Primarily:

It has the convenience of Meek, but can support magnitudes more
users with negligible CDN costs. (Domain fronting is only used for brief
signalling / NAT-piercing to setup the P2P WebRTC DataChannels which handle
the actual traffic.)

Arbitrarily high numbers of volunteer proxies are possible like in
flashproxy, but NATs are no longer a usability barrier - no need for
manual port forwarding!

**Q: Why is this called Snowflake?**
It utilizes the "ICE" negotiation via WebRTC, and also involves a great
abundance of ephemeral and short-lived (and special!) volunteer proxies...

## Open UI: Stats Dashboard

Clicking **Open UI** in the StartOS dashboard for this service shows a live stats page with:

- **NAT type** — whether your proxy is reachable directly ("unrestricted") or only through relayed connections ("restricted"), as determined by the proxy itself shortly after each start.
- **Bandwidth** totals for today, the last 7 days, the last 30 days, and all-time.
- **Connections** in the most recent completed hour.
- A **bar chart** and table of recent hourly activity.

The page refreshes itself automatically every 5 minutes. Everything shown is computed from the proxy's own log output and stored on this service's persistent volume, so history survives restarts and updates — but it starts from zero the first time this dashboard feature is installed, since it has no earlier log data to draw from.
