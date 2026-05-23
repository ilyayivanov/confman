SOCKETD_DIRECTORY="/etc/systemd/system/ssh.socket.d"
SOCKETD_CONF_FILE="${SOCKETD_DIRECTORY}/addresses.conf"

function change_ssh_port() {
    local SSH_PORT=${1}
    if [[ ! ${SSH_PORT} =~ [0-9] ]]; then
        echo "Не передан номер порта"
        return 1
    fi

    echo "Начало смены SSH-порта на ${SSH_PORT}"

    sudo mkdir -p ${SOCKETD_DIRECTORY}

    local SOCKET_BLOCK='/\[Socket\]/,/ListenStream=[0-9]+/'
	if [ ! -f ${SOCKETD_CONF_FILE} ] || awk "${SOCKET_BLOCK} {found=1; exit} END {exit found}" ${SOCKETD_CONF_FILE}; then
        echo "Запись конфигурации в файл ${SOCKETD_CONF_FILE}"

		sudo tee -a ${SOCKETD_CONF_FILE} > /dev/null <<-EOF
			[Socket]
			ListenStream=
			ListenStream=${SSH_PORT}
		EOF

        echo "Новая конфигурация записана в файл ${SOCKETD_CONF_FILE}"
    else
        echo "Найдена существующая конфигурация SSH-порта в файле ${SOCKETD_CONF_FILE}. Начало изменения конфигурации"

        local REPLACE_PATTERN="${SOCKET_BLOCK} { gsub(/ListenStream=[0-9]+/, \"ListenStream=${SSH_PORT}\") } 1"
        local TEMP_FILE="${SOCKETD_CONF_FILE}.$(date +%s%3N)"

        sudo awk "${REPLACE_PATTERN}" ${SOCKETD_CONF_FILE} | sudo tee "${TEMP_FILE}" > /dev/null && sudo mv ${TEMP_FILE} ${SOCKETD_CONF_FILE}

        echo "Обновленная конфигурация записана в файл ${SOCKETD_CONF_FILE}"
    fi

    echo "Перезапуск сокета для применения нового порта"

    # Reload systemd to recognize the new override file
    sudo systemctl daemon-reload
    # Restart the socket to apply the new port immediately
    sudo systemctl restart ssh.socket
    # Ensure firewall allows the new port
    sudo ufw allow "${SSH_PORT}/tcp"
    sudo ufw reload

    echo "SSH-порт изменен на ${SSH_PORT}"
}