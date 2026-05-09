#!/bin/bash

# https://habr.com/ru/articles/869340/

apt update -y

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Выполнить и сохранить вывод
xray uuid
xray x25519

# Сайт, на котором будет работать соединение
curl -I --tlsv1.3 --http2 https://vk.com/
openssl s_client -connect vk.com:443 -brief

# Заполнить config.json и заменить им /usr/local/etc/xray/config.json

systemctl restart xray
systemctl status xray

# Строка для подключения
# vless://<uuid из шага 2>@<IP-адрес сервера>:443?type=tcp&security=reality&pbk=<публичный ключ из шага 2>&fp=chrome&sni=<домен из serverNames в конфиге>&sid=<одно из значений shortIds в конфиге>&flow=xtls-rprx-vision#<произвольное название, под которым профиль будет сохранён в приложении>

# Сгенерировать QR-code для подключения
apt install qrencode -y
qrencode -o qr.png 'vless://...'
