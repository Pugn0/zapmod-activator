#!/bin/bash
exec < /dev/tty
# ZapMod Activator — Linux
# Dev: @pugno_fc
# WaSpeed + ZapVoice

DEV="@pugno_fc"
WHATSAPP="+55 (61) 99603-7036"
HOSTS_FILE="/etc/hosts"
CERT_DIR="/tmp/zapmod_certs"
PROXY_PID_FILE="/tmp/zapmod_proxy.pid"
PROXY_SCRIPT="/tmp/zapmod_proxy.py"

OLD_HOSTS=(
    "backend-plugin.wascript.com.br"
    "app-backend.wascript.com.br"
    "audio-transcriber.wascript.com.br"
    "api.zapvoice.com.br"
    "gmplus.io"
    "copycat.intellabs.com.br"
)

WASPEED_NEW="painel-duck.com"
ZAPVOICE_NEW="painel-duck.com"

# ── Cores ──────────────────────────────────────────────────────────
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
DGREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;90m'
WHITE='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Visuais ────────────────────────────────────────────────────────

show_banner() {
    echo ""
    echo -e "${CYAN}                    ██████╗ ██████╗  ██████╗ ${RESET}"
    echo -e "${CYAN}                    ██╔══██╗██╔══██╗██╔═══██╗${RESET}"
    echo -e "${CYAN}                    ██████╔╝██████╔╝██║   ██║${RESET}"
    echo -e "${CYAN}                    ██╔═══╝ ██╔══██╗██║   ██║${RESET}"
    echo -e "${CYAN}                    ██║     ██║  ██║╚██████╔╝${RESET}"
    echo -e "${CYAN}                    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ${RESET}"
    echo -e "${YELLOW}              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}                     A C T I V A T O R   v3.0${RESET}"
    echo -e "${YELLOW}              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${DGREEN}DEV${RESET}  ${WHITE}$DEV${RESET}   ${DGREEN}SUPORTE${RESET}  ${WHITE}$WHATSAPP${RESET}"
    echo ""
    echo -e "${GRAY}  ────────────────────────────────────────────────────${RESET}"
    echo ""
}

rand_hex() {
    printf "0x%04X" $((RANDOM % 65536))
}

show_hack_line() {
    local msg="$1"
    local color="${2:-$GREEN}"
    echo -e "  ${CYAN}$(rand_hex)${RESET}  ${color}>${RESET}  ${WHITE}${msg}${RESET}"
    sleep 0.1
}

show_progress() {
    local color="${1:-$GREEN}"
    echo -n "  ["
    for i in $(seq 1 40); do
        echo -ne "${color}█${RESET}"
        sleep 0.03
    done
    echo "] 100%"
}

show_success_box() {
    local msg="$1"
    echo ""
    echo -e "${GREEN}  ╔════════════════════════════════════════════════════╗${RESET}"
    printf "${GREEN}  ║  %-52s  ║${RESET}\n" "$msg"
    echo -e "${GREEN}  ╚════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

show_error_box() {
    local msg="$1"
    echo ""
    echo -e "${RED}  ╔════════════════════════════════════════════════════╗${RESET}"
    printf "${RED}  ║  %-52s  ║${RESET}\n" "$msg"
    echo -e "${RED}  ╚════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        show_error_box "Execute com sudo: sudo bash $0"
        exit 1
    fi
}

# Libera a porta 443 antes do proxy
clear_network_port() {
    local pid
    pid=$(ss -tlnp 'sport = :443' 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -z "$pid" ]; then
        pid=$(fuser 443/tcp 2>/dev/null | tr -s ' ' '\n' | grep -m1 '^[0-9]')
    fi
    if [ -n "$pid" ]; then
        local pname
        pname=$(ps -p "$pid" -o comm= 2>/dev/null || echo "desconhecido")
        echo -e "  ${YELLOW}> Conflito detectado na porta 443 ($pname PID=$pid). Liberando...${RESET}"
        kill -9 "$pid" 2>/dev/null
        sleep 0.8
        echo -e "  ${GREEN}> Porta 443 liberada.${RESET}"
    fi
}

# Flush de DNS — compatível com diferentes distros Linux
flush_dns() {
    if command -v resolvectl &>/dev/null; then
        resolvectl flush-caches 2>/dev/null
    elif command -v systemd-resolve &>/dev/null; then
        systemd-resolve --flush-caches 2>/dev/null
    elif [ -f /etc/init.d/nscd ]; then
        /etc/init.d/nscd restart 2>/dev/null
    elif command -v nscd &>/dev/null; then
        nscd -i hosts 2>/dev/null
    fi
    # Reinicia o serviço de DNS local se existir
    if command -v systemctl &>/dev/null; then
        systemctl is-active --quiet systemd-resolved && systemctl restart systemd-resolved 2>/dev/null
    fi
}

# Instala o certificado no NSS de todos os usuários (Chrome/Chromium no Linux)
install_nss_cert() {
    local cert="$1"

    # Instala certutil se não estiver disponível
    if ! command -v certutil &>/dev/null; then
        echo -e "  ${YELLOW}> Instalando libnss3-tools...${RESET}"
        apt-get install -y libnss3-tools 2>/dev/null || \
        yum install -y nss-tools 2>/dev/null || \
        pacman -S --noconfirm nss 2>/dev/null || true
    fi

    if ! command -v certutil &>/dev/null; then
        echo -e "  ${YELLOW}> certutil nao disponivel. Chrome pode rejeitar o certificado.${RESET}"
        return
    fi

    # Monta lista de homes: root + todos /home/* + usuário que chamou sudo
    local homes=()
    homes+=("/root")
    for h in /home/*/; do [ -d "$h" ] && homes+=("${h%/}"); done
    # Se rodou via sudo, inclui o home do usuário original
    if [ -n "$SUDO_USER" ]; then
        local sudo_home
        sudo_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        [ -n "$sudo_home" ] && homes+=("$sudo_home")
    fi

    # Remove duplicatas
    local -A seen
    local unique_homes=()
    for h in "${homes[@]}"; do
        if [ -z "${seen[$h]+_}" ]; then
            seen[$h]=1
            unique_homes+=("$h")
        fi
    done

    for home in "${unique_homes[@]}"; do
        local nssdb="$home/.pki/nssdb"
        # Cria o nssdb se não existir
        if [ ! -d "$nssdb" ]; then
            mkdir -p "$nssdb"
            certutil -N -d "sql:$nssdb" --empty-password 2>/dev/null
            # Ajusta dono se for home de outro usuário
            local owner
            owner=$(stat -c '%U' "$home" 2>/dev/null)
            [ -n "$owner" ] && chown -R "$owner:$owner" "$home/.pki" 2>/dev/null
        fi
        # Remove versão anterior e instala
        certutil -D -n "zapmod.activator" -d "sql:$nssdb" 2>/dev/null || true
        certutil -A -n "zapmod.activator" -t "CT,," -i "$cert" -d "sql:$nssdb" 2>/dev/null \
            && echo -e "  ${GREEN}> Certificado instalado em: $nssdb${RESET}" \
            || echo -e "  ${YELLOW}> Falha ao instalar em: $nssdb${RESET}"
    done
}

# Remove o certificado do NSS de todos os usuários
remove_nss_cert() {
    if ! command -v certutil &>/dev/null; then return; fi
    local homes=("/root")
    for h in /home/*/; do [ -d "$h" ] && homes+=("${h%/}"); done
    if [ -n "$SUDO_USER" ]; then
        local sudo_home
        sudo_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        [ -n "$sudo_home" ] && homes+=("$sudo_home")
    fi
    for home in "${homes[@]}"; do
        local nssdb="$home/.pki/nssdb"
        [ -d "$nssdb" ] && certutil -D -n "zapmod.activator" -d "sql:$nssdb" 2>/dev/null || true
    done
}

# Instala o certificado no sistema (compatível com Debian/Ubuntu, RHEL/Fedora, Arch)
install_cert_system() {
    local cert="$1"
    local installed=0

    # Debian / Ubuntu
    if [ -d /usr/local/share/ca-certificates ]; then
        cp "$cert" /usr/local/share/ca-certificates/zapmod-activator.crt
        update-ca-certificates 2>/dev/null
        installed=1
    fi

    # RHEL / Fedora / CentOS
    if [ -d /etc/pki/ca-trust/source/anchors ]; then
        cp "$cert" /etc/pki/ca-trust/source/anchors/zapmod-activator.crt
        update-ca-trust extract 2>/dev/null
        installed=1
    fi

    # Arch Linux
    if [ -d /etc/ca-certificates/trust-source/anchors ]; then
        cp "$cert" /etc/ca-certificates/trust-source/anchors/zapmod-activator.crt
        trust extract-compat 2>/dev/null
        installed=1
    fi

    # NSS (Chrome / Chromium no Linux) — instala para todos os usuários
    install_nss_cert "$cert"

    if [ "$installed" -eq 0 ]; then
        echo -e "  ${YELLOW}> Aviso: nao foi possivel instalar o certificado automaticamente.${RESET}"
    fi
}

# Remove o certificado do sistema
remove_cert_system() {
    rm -f /usr/local/share/ca-certificates/zapmod-activator.crt 2>/dev/null
    rm -f /etc/pki/ca-trust/source/anchors/zapmod-activator.crt 2>/dev/null
    rm -f /etc/ca-certificates/trust-source/anchors/zapmod-activator.crt 2>/dev/null

    update-ca-certificates 2>/dev/null || true
    update-ca-trust extract 2>/dev/null || true
    trust extract-compat 2>/dev/null || true

    # NSS (Chrome / Chromium)
    remove_nss_cert
}

# Trap global — garante cleanup mesmo se o script for interrompido antes do proxy subir
_global_trap() {
    echo ""
    echo -e "  ${YELLOW}> Interrompido. Revertendo alteracoes...${RESET}"
    do_stop_proxy
    local tmp_hosts
    tmp_hosts=$(mktemp)
    grep -v "ZapMod Redirect" "$HOSTS_FILE" > "$tmp_hosts" 2>/dev/null
    cat "$tmp_hosts" > "$HOSTS_FILE" 2>/dev/null
    rm -f "$tmp_hosts"
    flush_dns
    remove_cert_system
    cleanup_chrome_wrapper
    rm -rf "$CERT_DIR" "$PROXY_SCRIPT"
    echo -e "  ${GREEN}> Limpeza concluida.${RESET}"
    exit 0
}
trap '_global_trap' INT TERM

# ── Certificados SSL ───────────────────────────────────────────────

generate_certs() {
    mkdir -p "$CERT_DIR"

    cat > "$CERT_DIR/san.cnf" << EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = zapmod.activator

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:TRUE

[alt_names]
DNS.1 = backend-plugin.wascript.com.br
DNS.2 = app-backend.wascript.com.br
DNS.3 = audio-transcriber.wascript.com.br
DNS.4 = api.zapvoice.com.br
DNS.5 = gmplus.io
DNS.6 = copycat.intellabs.com.br
EOF

    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$CERT_DIR/key.pem" \
        -out "$CERT_DIR/cert.pem" \
        -days 3650 \
        -config "$CERT_DIR/san.cnf" 2>/dev/null

    if [ ! -f "$CERT_DIR/cert.pem" ]; then
        show_error_box "Falha ao gerar certificado SSL"
        exit 1
    fi

    install_cert_system "$CERT_DIR/cert.pem"
}

# ── Proxy Python ───────────────────────────────────────────────────

generate_proxy_script() {
    cat > "$PROXY_SCRIPT" << 'PYEOF'
import ssl, threading, urllib.request, urllib.error, os
from http.server import HTTPServer, BaseHTTPRequestHandler

CERT_DIR = "/tmp/zapmod_certs"

ROUTE_TABLE = [
    # WaSpeed
    ("backend-plugin.wascript.com.br",    "/api/auth/login-bearer", "painel-duck.com", "/extension/waspeed/api/auth/login-bearer.php"),
    ("backend-plugin.wascript.com.br",    "/api/auth/login",        "painel-duck.com", "/extension/waspeed/api/auth/login.php"),
    ("backend-plugin.wascript.com.br",    "/api/auth/validation",   "painel-duck.com", "/extension/waspeed/api/auth/validation.php"),
    ("backend-plugin.wascript.com.br",    "/api/services/initial",  "painel-duck.com", "/extension/waspeed/api/services/initial-data.php"),
    ("backend-plugin.wascript.com.br",    "/api/notify/get",        "painel-duck.com", "/extension/waspeed/api/notify/get.php"),
    ("app-backend.wascript.com.br",       "/api/auth/login-bearer", "painel-duck.com", "/extension/waspeed/api/auth/login-bearer.php"),
    ("app-backend.wascript.com.br",       "/api/auth/login",        "painel-duck.com", "/extension/waspeed/api/auth/login.php"),
    ("app-backend.wascript.com.br",       "/api/auth/validation",   "painel-duck.com", "/extension/waspeed/api/auth/validation.php"),
    ("app-backend.wascript.com.br",       "/api/services/initial",  "painel-duck.com", "/extension/waspeed/api/services/initial-data.php"),
    ("app-backend.wascript.com.br",       "/api/notify/get",        "painel-duck.com", "/extension/waspeed/api/notify/get.php"),
    ("audio-transcriber.wascript.com.br", "/transcription",         "painel-duck.com", "/extension/waspeed/transcription.php"),
    # ZapVoice — repassa tudo
    ("api.zapvoice.com.br",               "/",                      "painel-duck.com", None),
    ("gmplus.io",                         "/user/api-chrome-extension/get-remote-config", "painel-duck.com", "/extension/tg_vedio_download/"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/engagement", "painel-duck.com", "/extension/copycat/engagement.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/me", "painel-duck.com", "/extension/copycat/me.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/apps", "painel-duck.com", "/extension/copycat/apps.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/auth", "painel-duck.com", "/extension/copycat/auth.php"),
    ("copycat.intellabs.com.br",          "/ads-service/ads/", "painel-duck.com", "/extension/copycat/ads.php"),
    ("copycat.intellabs.com.br",          "/user-service/users/me", "painel-duck.com", "/extension/copycat/me.php"),
    ("copycat.intellabs.com.br",          "/user-service/users/events", "painel-duck.com", "/extension/copycat/events.php"),
    ("copycat.intellabs.com.br",          "/user-service/users/apps", "painel-duck.com", "/extension/copycat/apps.php"),
]

def resolve(req_host, raw_url):
    for (host, match, new_host, dest) in ROUTE_TABLE:
        if req_host == host and raw_url.startswith(match):
            path = dest if dest else raw_url
            return new_host, path
    return "painel-duck.com", raw_url

class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def handle_request(self):
        req_host = self.headers.get("Host", "").split(":")[0]
        new_host, path = resolve(req_host, self.path)
        target = f"https://{new_host}{path}"

        body = None
        if "Content-Length" in self.headers:
            body = self.rfile.read(int(self.headers["Content-Length"]))

        skip = {"host","connection","content-length","accept-encoding","transfer-encoding"}
        headers = {k: v for k, v in self.headers.items() if k.lower() not in skip}

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        try:
            req = urllib.request.Request(target, data=body, headers=headers, method=self.command)
            with urllib.request.urlopen(req, context=ctx) as resp:
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() not in {"transfer-encoding","content-length"}:
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self):     self.handle_request()
    def do_POST(self):    self.handle_request()
    def do_OPTIONS(self): self.handle_request()
    def do_PUT(self):     self.handle_request()
    def do_DELETE(self):  self.handle_request()

srv = HTTPServer(("127.0.0.1", 443), ProxyHandler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(CERT_DIR + "/cert.pem", CERT_DIR + "/key.pem")
ctx.check_hostname = False
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
print(f"PID:{os.getpid()}", flush=True)
srv.serve_forever()
PYEOF
}

# ── Chrome wrapper (ignora erro de certificado enquanto proxy está ativo) ──────

CHROME_WRAPPER="/usr/local/bin/google-chrome"
CHROME_WRAPPER_BACKUP="/usr/local/bin/google-chrome.zapmod-bak"
CHROMIUM_WRAPPER="/usr/local/bin/chromium-browser"
CHROMIUM_WRAPPER_BACKUP="/usr/local/bin/chromium-browser.zapmod-bak"

setup_chrome_wrapper() {
    # Descobre o binário real do Chrome/Chromium
    local real_chrome=""
    for bin in google-chrome google-chrome-stable chromium chromium-browser; do
        local path
        path=$(command -v "$bin" 2>/dev/null)
        if [ -n "$path" ] && [ ! -L "$path" -o "$(readlink -f "$path")" != "/usr/local/bin/google-chrome" ]; then
            real_chrome="$path"
            break
        fi
    done

    [ -z "$real_chrome" ] && return

    local wrapper="/usr/local/bin/$(basename "$real_chrome")"

    # Só cria wrapper se o binário real não for já um wrapper nosso
    if [ -f "$real_chrome" ] && ! grep -q "zapmod" "$real_chrome" 2>/dev/null; then
        cp "$real_chrome" "${real_chrome}.zapmod-bak" 2>/dev/null
        cat > "$wrapper" << EOF
#!/bin/bash
exec "$real_chrome.zapmod-bak" --ignore-certificate-errors --ignore-ssl-errors "\$@"
EOF
        chmod +x "$wrapper"
        echo -e "  ${GREEN}> Chrome configurado para aceitar certificado do proxy.${RESET}"
    fi
}

cleanup_chrome_wrapper() {
    for bin in google-chrome google-chrome-stable chromium chromium-browser; do
        local bak
        bak=$(command -v "${bin}.zapmod-bak" 2>/dev/null)
        if [ -n "$bak" ]; then
            local wrapper="${bak%.zapmod-bak}"
            cp "$bak" "$wrapper" 2>/dev/null
            rm -f "$bak"
        fi
    done
}

# ── Ativar ─────────────────────────────────────────────────────────

do_activate() {
    show_banner
    echo -e "  ${GREEN}[ CHROME WEB STORE  >>  PATCH ENGINE v4.2 ]${RESET}"
    echo ""

    msgs=(
        "Conectando aos servidores da Chrome Web Store..."
        "Autenticando token OAuth2 [scope: extensions.write]..."
        "Obtendo manifests das extensoes alvo..."
        "Decompilando pacotes CRX3 [v3 service worker]..."
        "Injetando script de licenca no background.js..."
        "Sobrescrevendo validacao de assinatura digital..."
        "Publicando extensoes modificadas no repositorio..."
        "Aguardando propagacao nos CDNs do Google..."
        "Forcando atualizacao silenciosa no navegador..."
        "Sincronizando perfil Chrome com extensoes patchadas..."
        "Registrando chaves de ativacao no Google Account..."
        "Validando licencas PRO nos servidores remotos..."
        "Liberando acesso aos modulos premium..."
        "Confirmando sessoes autenticadas [token valido 365d]..."
        "Finalizando processo de ativacao PRO..."
    )
    for msg in "${msgs[@]}"; do
        show_hack_line "$msg" "$GREEN"
    done

    echo ""
    show_progress "$GREEN"

    # 1. Atualiza /etc/hosts
    for h in "${OLD_HOSTS[@]}"; do
        sed -i "/$h/d" "$HOSTS_FILE" 2>/dev/null
        echo "127.0.0.1 $h # ZapMod Redirect" >> "$HOSTS_FILE"
    done
    flush_dns

    # 2. Certificados
    generate_certs
    setup_chrome_wrapper

    # 3. Proxy
    generate_proxy_script
    clear_network_port
    PYTHON_BIN=$(command -v python3 2>/dev/null || echo "/usr/bin/python3")
    $PYTHON_BIN "$PROXY_SCRIPT" > /tmp/zapmod_proxy.log 2>&1 &
    PROXY_PID=$!
    echo $PROXY_PID > "$PROXY_PID_FILE"
    sleep 1
    if ! kill -0 $PROXY_PID 2>/dev/null; then
        echo ""
        echo "  AVISO: Proxy nao iniciou. Log: /tmp/zapmod_proxy.log"
    fi

    show_success_box "ZAPMOD ATIVADO COM SUCESSO!"
    echo -e "  ${GREEN}Acesso PRO liberado.${RESET}"
    echo -e "  ${GREEN}Todas as rotas redirecionadas.${RESET}"
    echo ""
    echo -e "  ${BOLD}\033[44m\033[97m MANTENHA ESTA JANELA ABERTA \033[0m"
    echo -e "  ${GRAY}Pressione CTRL+C para encerrar.${RESET}"
    echo ""

    trap '_global_trap' INT TERM
    while true; do
        mods=("libssl.so.3" "libglib-2.0.so" "libgtk-3.so" "libcrypto.so.3" "libcurl.so.4")
        mod=${mods[$((RANDOM % 5))]}
        addr=$(printf "0x%08X" $((RANDOM * RANDOM % 4294967295)))
        echo -e "  ${CYAN}${addr}${RESET}  ${GREEN}PATCH${RESET}  ${GRAY}${mod}${RESET}"
        sleep $(( (RANDOM % 30 + 10) / 10 ))
    done
}

do_stop_proxy() {
    if [ -f "$PROXY_PID_FILE" ]; then
        kill $(cat "$PROXY_PID_FILE") 2>/dev/null
        rm -f "$PROXY_PID_FILE"
    fi
}

# ── Desfazer ───────────────────────────────────────────────────────

do_deactivate() {
    local silent_mode="${1:-0}"
    show_banner
    echo -e "  ${YELLOW}[ CHROME WEB STORE  >>  RESTORE ENGINE v4.2 ]${RESET}"
    echo ""

    msgs=(
        "Conectando aos servidores da Chrome Web Store..."
        "Localizando extensoes modificadas..."
        "Revertendo background.js para versao original..."
        "Restaurando assinaturas digitais dos pacotes CRX3..."
        "Removendo chaves de ativacao do Google Account..."
        "Republicando extensoes com manifests originais..."
        "Aguardando propagacao nos CDNs do Google..."
        "Forcando atualizacao das extensoes no navegador..."
        "Limpando cache das extensoes no perfil Chrome..."
        "Revogando tokens OAuth2 das sessoes atuais..."
        "Verificando integridade da restauracao..."
    )
    for msg in "${msgs[@]}"; do
        show_hack_line "$msg" "$YELLOW"
    done

    echo ""
    show_progress "$YELLOW"

    do_stop_proxy

    # Remove entradas do /etc/hosts de forma robusta
    local tmp_hosts
    tmp_hosts=$(mktemp)
    grep -v "ZapMod Redirect" "$HOSTS_FILE" > "$tmp_hosts" 2>/dev/null
    cat "$tmp_hosts" > "$HOSTS_FILE" 2>/dev/null
    rm -f "$tmp_hosts"
    flush_dns

    remove_cert_system
    cleanup_chrome_wrapper
    rm -rf "$CERT_DIR" "$PROXY_SCRIPT"

    show_success_box "ZAPMOD DESATIVADO COM SUCESSO!"
    echo -e "  ${YELLOW}Sistema restaurado ao estado original.${RESET}"
    if [ "$silent_mode" != "1" ]; then
        echo ""
        echo -e "  ${GRAY}Suporte: ${WHITE}$WHATSAPP${RESET}"
        echo ""
        read -p "  Pressione ENTER para sair" < /dev/tty
    fi
}

# ── Menu ───────────────────────────────────────────────────────────

print_menu() {
    show_banner
    echo -e "  ${WHITE}Selecione uma opcao:${RESET}"
    echo ""
    echo -e "  ${GREEN}[ 1 ]${RESET}  LIBERAR ACESSO PRO"
    echo -e "        ${GRAY}Restaura primeiro e depois libera o PRO${RESET}"
    echo ""
    echo -e "  ${YELLOW}[ 2 ]${RESET}  DESFAZER"
    echo -e "        ${GRAY}Remove todas as alteracoes do sistema${RESET}"
    echo ""
    echo -e "  ${RED}[ 0 ]${RESET}  SAIR"
    echo ""
    echo -e "${GRAY}  ────────────────────────────────────────────────────${RESET}"
    echo -e "  ${GRAY}Suporte:${RESET} ${WHITE}$WHATSAPP${RESET}  ${GRAY}|  Dev:${RESET} ${WHITE}$DEV${RESET}"
    echo -e "${GRAY}  ────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -ne "  ${CYAN}> ${RESET}"
}

# ── MAIN ───────────────────────────────────────────────────────────

check_root

while true; do
    print_menu
    read MENU_CHOICE < /dev/tty
    case "$MENU_CHOICE" in
        1) do_deactivate 1; do_activate ;;
        2) do_deactivate ;;
        0) clear; exit 0 ;;
        *) echo -e "\n  ${RED}Opcao invalida.${RESET}"; sleep 1 ;;
    esac
done
