/ip/route/add dst-address=8.8.8.8/32 gateway=wg-awg-proxy-1 comment=awg-proxy-1-tunnel
/ip/route/add dst-address=100.0.0.0/8 gateway=wg-awg-proxy-1 comment=awg-proxy-1-tunnel

/ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=to-awg passthrough=yes dst-address-list=ai_cidr4
/ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=to-awg passthrough=yes dst-address-list=jetbrains_cidr4
/ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=to-awg passthrough=yes dst-address-list=messengers_cidr4
/ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=to-awg passthrough=yes dst-address-list=news_cidr4
/ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=to-awg passthrough=yes dst-address-list=torrent_cidr4
/ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=to-awg passthrough=yes dst-address-list=youtube_cidr4

/ip route add dst-address=0.0.0.0/0 gateway=wg-awg-proxy-1 routing-table=to-awg comment=awg-proxy-1-tunnel
