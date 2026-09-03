#!/bin/bash
OS="$(uname -s)"
case "$OS" in
    Darwin)
        curl -fsSL https://raw.githubusercontent.com/Pugn0/zapmod-activator/main/activator.sh | sed 's/\r//' > /tmp/zapmod.sh && sudo bash /tmp/zapmod.sh
        ;;
    Linux)
        curl -fsSL https://raw.githubusercontent.com/Pugn0/zapmod-activator/main/activator-linux.sh | sed 's/\r//' > /tmp/zapmod.sh && sudo bash /tmp/zapmod.sh
        ;;
    *)
        echo "Sistema operacional nao suportado: $OS"
        exit 1
        ;;
esac
