function change_ssh_port() {
    SSH_PORT=${1}
    if [[ ${SSH_PORT} =~ [0-9] ]]; then
        echo "Не передан номер порта"
        return 1
    fi

    # 1. Create the systemd override directory for ssh.socket if it doesn't exist
    mkdir -p /etc/systemd/system/ssh.socket.d/

    # 2. Write the port configuration override file
    cat <<-EOF > /etc/systemd/system/ssh.socket.d/addresses.conf
    [Socket]
    ListenStream=
    ListenStream=${SSH_PORT}
    EOF

    # TODO доделать

    # 3. Reload systemd to recognize the new override file
    # systemctl daemon-reload

    # 4. Restart the socket to apply the new port immediately
    # systemctl restart ssh.socket
}