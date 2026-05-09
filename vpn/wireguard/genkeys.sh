NAME=$1
wg genkey | tee ./${NAME}_privatekey | wg pubkey | tee ./${NAME}_publickey
