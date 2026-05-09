/interface wireguard
add listen-port=46748 mtu=1420 name=wg-lochim private-key=\
    "todo_private_key"
/routing table
add disabled=no fib name=lochim-mark
/interface wireguard peers
add allowed-address=0.0.0.0/0,::/0 endpoint-address=194.87.140.240 \
    endpoint-port=todo_port interface=todo_interface_name name=todo_peer_name public-key=\
    "todo_public_key" \
    persistent-keepalive 25
/ip address
add address=todo_address interface=todo_interface_name network=todo_network
/ip firewall nat
add action=masquerade chain=srcnat out-interface=todo_interface_name
/ip route
add disabled=no distance=1 dst-address=0.0.0.0/0 gateway=todo_interface_name \
    routing-table=todo_routing_table_name suppress-hw-offload=no
