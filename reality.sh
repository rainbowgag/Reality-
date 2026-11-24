#!/usr/bin/env bash
#
# VLESS + Reality 一键安装 / 管理脚本（Xray 内核）
# 交互项：节点名称、SNI 域名、端口；其余参数每次创建随机。
# 安装完成后，在终端输入 ry 即可打开管理菜单。
#

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/rainbowgag/Reality-/master/reality.sh"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
META_DIR="/usr/local/etc/reality"
META_FILE="${META_DIR}/node.conf"
MANAGE_SCRIPT="/usr/local/bin/reality-manage.sh"
RY_BIN="/usr/local/bin/ry"

log()  { printf '\033[1;32m[信息]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[警告]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2; }

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "请使用 root 权限运行：sudo bash $0"
    exit 1
  fi
}

fetch_url() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -4fsSL --connect-timeout 8 --max-time 15 "$url" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -4qO- --timeout=15 "$url" 2>/dev/null
  else
    return 1
  fi
}

urlencode() {
  local s="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$s"
  elif command -v python >/dev/null 2>&1; then
    python -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$s"
  else
    local encoded="" c o i
    local len=${#s}
    for ((i = 0; i < len; i++)); do
      c="${s:i:1}"
      case "$c" in
        [a-zA-Z0-9.~_-]) o="$c" ;;
        *) printf -v o '%%%02X' "'$c" ;;
      esac
      encoded+="$o"
    done
    printf '%s' "$encoded"
  fi
}

json_quote() {
  local s="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$s"
  elif command -v python >/dev/null 2>&1; then
    python -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$s"
  else
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '"%s"' "$s"
  fi
}

save_var() {
  printf '%s=%q\n' "$1" "$2" >> "$META_FILE"
}

get_public_ip() {
  local ip=""
  for url in \
    "https://api.ipify.org" \
    "https://ifconfig.me/ip" \
    "https://ipinfo.io/ip" \
    "https://api64.ipify.org"; do
    ip="$(fetch_url "$url" | tr -d '\r\n' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1 || true)"
    [ -n "$ip" ] && break
  done
  if [ -z "$ip" ]; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [ -z "$ip" ]; then
    ip="$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
  fi
  printf '%s' "$ip"
}

normalize_sni() {
  local s="$1"
  s="$(printf '%s' "$s" | tr -d '[:space:]')"
  s="${s#*://}"
  s="${s%%/*}"
  s="${s%%:*}"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$s"
}

get_country_code() {
  local ip="$1"
  local cc=""

  cc="$(fetch_url "https://ipinfo.io/${ip}/json" 2>/dev/null | sed -nE 's/.*"country"[[:space:]]*:[[:space:]]*"([A-Za-z]{2})".*/\1/p' | head -n1 || true)"
  if [ -z "$cc" ]; then
    cc="$(fetch_url "https://ipapi.co/${ip}/json/" 2>/dev/null | sed -nE 's/.*"country_code"[[:space:]]*:[[:space:]]*"([A-Za-z]{2})".*/\1/p' | head -n1 || true)"
  fi
  if [ -z "$cc" ]; then
    cc="$(fetch_url "https://ipwho.is/${ip}" 2>/dev/null | sed -nE 's/.*"country_code"[[:space:]]*:[[:space:]]*"([A-Za-z]{2})".*/\1/p' | head -n1 || true)"
  fi
  if [ -z "$cc" ]; then
    cc="$(fetch_url "http://ip-api.com/json/${ip}?fields=status,countryCode" 2>/dev/null | sed -nE 's/.*"countryCode"[[:space:]]*:[[:space:]]*"([A-Za-z]{2})".*/\1/p' | head -n1 || true)"
  fi

  printf '%s' "$(printf '%s' "$cc" | tr '[:lower:]' '[:upper:]')"
}

get_sni_candidates() {
  case "$1" in
    US)
      echo "computerhistory.org www.exploratorium.edu www.cmog.org www.thehenryford.org www.museumofplay.org www.montereybayaquarium.org"
      ;;
    GB)
      echo "www.railwaymuseum.org.uk www.scienceandmediamuseum.org.uk www.wealddown.co.uk www.rmg.co.uk www.nationaltrust.org.uk"
      ;;
    DE)
      echo "www.technik-museum.de www.phaeno.de www.dasa-dortmund.de www.museumfuernaturkunde.berlin www.senckenberg.de"
      ;;
    JP)
      echo "www.kobe-oukoku.com kyotomm.jp www.tepia.jp www.kaiyukan.com www.ghibli-museum.jp"
      ;;
    KR)
      echo "www.sciencecenter.go.kr www.samsung.com"
      ;;
    FR)
      echo "www.cite-espace.com www.musee-marine.fr museedesconfluences.fr"
      ;;
    SG)
      echo "www.science.edu.sg www.peranakanmuseum.nhb.gov.sg www.nationalgallery.sg www.gardensbythebay.com.sg"
      ;;
    MY)
      echo "iamm.org.my www.royalselangor.com museumvolunteersjmm.com www.gamudaland.com.my"
      ;;
    TW)
      echo "beitoumuseum.org.tw www.huashan1914.com www.opentix.life www.nmtl.gov.tw www.ntm.gov.tw www.ntmofa.gov.tw www.nmp.gov.tw"
      ;;
    HK)
      echo "www.kfbg.org hk.science.museum www.hkmemory.hk www.mplus.org.hk"
      ;;
    *)
      echo "lightnode.com inet.ws"
      ;;
  esac
}

measure_latency() {
  local domain="$1"
  local out ms
  out="$(curl -4s --connect-timeout 2 --max-time 4 -o /dev/null -w '%{time_connect}' "https://${domain}/" 2>/dev/null || true)"
  ms="$(printf '%s' "$out" | awk '{printf "%.0f", $1 * 1000}' 2>/dev/null || true)"
  if [[ "$ms" =~ ^[0-9]+$ ]] && [ "$ms" -gt 0 ]; then
    printf '%s' "$ms"
  else
    printf ''
  fi
}

select_default_sni() {
  local candidates best best_ms domain ms
  candidates="$(get_sni_candidates "$1")"
  best=""
  best_ms=999999

  for domain in $candidates; do
    domain="$(normalize_sni "$domain")"
    ms="$(measure_latency "$domain")"
    if [ -n "$ms" ] && [ "$ms" -lt "$best_ms" ]; then
      best="$domain"
      best_ms="$ms"
    fi
  done

  if [ -z "$best" ]; then
    best="$(printf '%s' "$candidates" | awk '{print $1}')"
  fi
  printf '%s' "$best"
}

make_server_names() {
  local s="$SNI"
  if [[ "$s" != www.* ]]; then
    printf '"%s","www.%s"' "$s" "$s"
  else
    printf '"%s","%s"' "$s" "${s#www.}"
  fi
}

install_xray() {
  if command -v xray >/dev/null 2>&1; then
    log "已检测到 Xray 内核，跳过安装。"
    return 0
  fi

  log "正在安装 Xray 内核..."
  local installer="/tmp/xray-install.sh"
  if ! fetch_url "https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh" > "$installer"; then
    err "下载 Xray 安装脚本失败，请检查网络。"
    exit 1
  fi
  bash "$installer" install
  rm -f "$installer"

  if ! command -v xray >/dev/null 2>&1; then
    err "Xray 安装失败。"
    exit 1
  fi
  log "Xray 内核安装完成。"
}

ensure_qrencode() {
  if command -v qrencode >/dev/null 2>&1; then
    return 0
  fi
  log "未检测到 qrencode，正在安装..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y qrencode >/dev/null 2>&1 || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y qrencode >/dev/null 2>&1 || true
  elif command -v yum >/dev/null 2>&1; then
    yum install -y qrencode >/dev/null 2>&1 || true
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache qrencode >/dev/null 2>&1 || true
  fi
}

generate_random() {
  UUID="$(xray uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || true)"
  if [ -z "$UUID" ]; then
    UUID="$(cat /proc/sys/kernel/random/uuid)"
  fi

  local keys
  keys="$(xray x25519 2>/dev/null || true)"
  PRIVATE_KEY="$(printf '%s\n' "$keys" | sed -nE 's/^PrivateKey:[[:space:]]*//p' | head -n1)"
  PUBLIC_KEY="$(printf '%s\n' "$keys" | sed -nE 's/^Password \(PublicKey\):[[:space:]]*//p' | head -n1)"
  if [ -z "$PUBLIC_KEY" ]; then
    PUBLIC_KEY="$(printf '%s\n' "$keys" | sed -nE 's/^PublicKey:[[:space:]]*//p' | head -n1)"
  fi
  if [ -z "$PUBLIC_KEY" ]; then
    PUBLIC_KEY="$(printf '%s\n' "$keys" | sed -nE 's/^Public key:[[:space:]]*//p' | head -n1)"
  fi
  if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
    err "生成 Reality 密钥对失败。"
    exit 1
  fi

  if command -v openssl >/dev/null 2>&1; then
    SHORT_ID="$(openssl rand -hex 4)"
  else
    SHORT_ID="$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  fi

  local fps=(chrome firefox safari edge android ios)
  FINGERPRINT="${fps[$((RANDOM % ${#fps[@]}))]}"
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tuln 2>/dev/null | awk '{print $5}' | grep -E ":${port}\$" >/dev/null 2>&1
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln 2>/dev/null | awk '{print $4}' | grep -E ":${port}\$" >/dev/null 2>&1
  else
    return 1
  fi
}

write_config() {
  mkdir -p "$CONFIG_DIR" "$META_DIR"
  cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality-in",
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI}:443",
          "xver": 0,
          "serverNames": [
            $(make_server_names)
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "",
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF
}

restart_xray() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable xray >/dev/null 2>&1 || true
    systemctl restart xray
  elif command -v service >/dev/null 2>&1; then
    service xray restart
  else
    warn "未检测到 systemctl/service，请手动启动 Xray。"
  fi
}

install_self() {
  local self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
  if [ ! -s "$self" ]; then
    self="/tmp/reality.sh"
    if ! fetch_url "$REPO_RAW" > "$self"; then
      warn "无法下载脚本副本，跳过 ry 命令安装。"
      return 0
    fi
  fi
  install -m 0755 "$self" "$MANAGE_SCRIPT"
  ln -sf "$MANAGE_SCRIPT" "$RY_BIN"
  log "管理命令 ry 已安装，后续输入 ry 即可打开菜单。"
}

save_meta() {
  : > "$META_FILE"
  save_var SERVER_IP "$SERVER_IP"
  save_var NODE_NAME "$NODE_NAME"
  save_var SNI "$SNI"
  save_var PORT "$PORT"
  save_var UUID "$UUID"
  save_var PUBLIC_KEY "$PUBLIC_KEY"
  save_var SHORT_ID "$SHORT_ID"
  save_var FINGERPRINT "$FINGERPRINT"
}

make_links() {
  local encoded_name
  encoded_name="$(urlencode "$NODE_NAME")"
  VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&security=reality&sni=${SNI}&fp=${FINGERPRINT}&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&spx=%2F&type=tcp&flow=xtls-rprx-vision&headerType=none#${encoded_name}"
  local name_q
  name_q="$(json_quote "$NODE_NAME")"
  CLASH_LINK="- {name: ${name_q}, type: vless, server: \"${SERVER_IP}\", port: ${PORT}, uuid: \"${UUID}\", network: tcp, tls: true, udp: true, servername: \"${SNI}\", flow: xtls-rprx-vision, client-fingerprint: ${FINGERPRINT}, reality-opts: {public-key: \"${PUBLIC_KEY}\", short-id: \"${SHORT_ID}\"}}"
}

show_info() {
  if [ ! -f "$META_FILE" ]; then
    err "未找到节点信息，请先执行安装脚本。"
    return 1
  fi
  # shellcheck disable=SC1090
  source "$META_FILE"
  make_links

  echo
  echo "==============================================="
  echo "  节点名称：${NODE_NAME}"
  echo "  服务器地址：${SERVER_IP}:${PORT}"
  echo "  SNI：${SNI}"
  echo "  Fingerprint：${FINGERPRINT}"
  echo "  UUID：${UUID}"
  echo "  公钥：${PUBLIC_KEY}"
  echo "  Short ID：${SHORT_ID}"
  echo "==============================================="
  echo
  echo "VLESS 节点链接："
  echo "${VLESS_LINK}"
  echo
  echo "Clash 节点（单排横向）："
  echo "${CLASH_LINK}"
  echo
  echo "二维码："
  ensure_qrencode
  if command -v qrencode >/dev/null 2>&1; then
    qrencode -t ANSIUTF8 -m 1 -s 4 "${VLESS_LINK}" 2>/dev/null || true
  else
    echo "未安装 qrencode，二维码生成失败。"
  fi
  echo
}

uninstall_xray() {
  log "正在卸载 Xray 节点..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
  elif command -v service >/dev/null 2>&1; then
    service xray stop >/dev/null 2>&1 || true
  fi
  rm -rf /usr/local/etc/xray
  rm -f /usr/local/bin/xray /usr/local/bin/xray-geodata /usr/local/bin/xray-shortcuts
  rm -f /etc/systemd/system/xray.service /etc/systemd/system/xray@.service
  rm -f /etc/systemd/system/multi-user.target.wants/xray.service
  systemctl daemon-reload >/dev/null 2>&1 || true
  log "Xray 节点已卸载。"
}

full_uninstall() {
  uninstall_xray
  rm -rf "$META_DIR"
  rm -f "$MANAGE_SCRIPT" "$RY_BIN"
  log "脚本、节点及 ry 命令已全部卸载。"
}

show_menu() {
  while true; do
    echo
    echo "======================================"
    echo "        VLESS + Reality 管理菜单      "
    echo "======================================"
    echo " 1) 查看节点信息 / 链接 / 二维码"
    echo " 2) 查看 Xray 状态"
    echo " 3) 重启 Xray"
    echo " 4) 卸载节点（保留本脚本与 ry 命令）"
    echo " 5) 完全卸载（节点 + 脚本 + ry 命令）"
    echo " 0) 退出"
    echo "======================================"
    read -rp "请输入选项 [0-5]：" choice
    case "$choice" in
      1) show_info || true ;;
      2)
        if command -v systemctl >/dev/null 2>&1; then
          systemctl status xray --no-pager 2>&1 || true
        elif command -v service >/dev/null 2>&1; then
          service xray status 2>&1 || true
        else
          warn "未检测到 systemctl/service。"
        fi
        ;;
      3)
        restart_xray
        log "Xray 已重启。"
        ;;
      4)
        read -rp "确认卸载 Xray 节点吗？[y/N]：" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          uninstall_xray
        else
          log "已取消。"
        fi
        ;;
      5)
        read -rp "确认完全卸载节点、脚本和 ry 命令吗？[y/N]：" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          full_uninstall
          echo "卸载完成，再见。"
          exit 0
        else
          log "已取消。"
        fi
        ;;
      0)
        exit 0
        ;;
      *)
        warn "无效选项。"
        ;;
    esac
  done
}

do_install() {
  need_root
  log "开始安装 VLESS + Reality 节点（Xray 内核）..."

  install_xray

  local default_ip
  default_ip="$(get_public_ip)"
  if [ -z "$default_ip" ]; then
    default_ip="127.0.0.1"
  fi

  echo
  echo "请设置节点参数（直接回车使用默认值）："
  read -rp "节点名称 [${default_ip}]：" NODE_NAME
  NODE_NAME="${NODE_NAME:-$default_ip}"

  local country_code default_sni
  country_code="$(get_country_code "$default_ip")"
  default_sni="$(select_default_sni "${country_code:-OTHER}")"
  if [ -z "$default_sni" ]; then
    default_sni="sony.com"
  fi
  if [ -n "$country_code" ]; then
    log "检测到服务器 IP 归属：${country_code}，已自动选择默认 SNI：${default_sni}"
  else
    log "未识别到 IP 归属国家，使用默认 SNI：${default_sni}"
  fi

  read -rp "SNI 域名 [${default_sni}]：" SNI
  SNI="$(normalize_sni "${SNI:-$default_sni}")"
  while [ -z "$SNI" ]; do
    warn "SNI 域名不能为空。"
    read -rp "SNI 域名 [${default_sni}]：" SNI
    SNI="$(normalize_sni "${SNI:-$default_sni}")"
  done

  read -rp "端口 [443]：" PORT
  PORT="${PORT:-443}"
  while ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; do
    warn "端口无效，请输入 1-65535 之间的数字。"
    read -rp "端口 [443]：" PORT
    PORT="${PORT:-443}"
  done

  if port_in_use "$PORT"; then
    warn "端口 ${PORT} 已被占用。"
    read -rp "仍要继续使用该端口吗？[y/N]：" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      err "已取消安装。"
      exit 1
    fi
  fi

  SERVER_IP="$default_ip"
  log "正在生成随机参数..."
  generate_random

  log "正在写入 Xray 配置..."
  write_config
  save_meta

  log "正在启动 Xray..."
  restart_xray
  install_self

  make_links
  show_info

  log "安装完成！以后在终端输入 ry 即可打开管理菜单。"
}

main() {
  case "${1:-}" in
    menu|manage)
      need_root
      show_menu
      ;;
    install)
      need_root
      do_install
      ;;
    uninstall)
      need_root
      full_uninstall
      ;;
    *)
      if [ -f "$META_FILE" ]; then
        need_root
        show_menu
      else
        do_install
      fi
      ;;
  esac
}

# 通过 ry 符号链接调用时进入菜单。
if [[ "$(basename "$0")" == "ry" || "$(basename "${BASH_SOURCE[0]}")" == "ry" || "$(basename "$0")" == "reality-manage.sh" ]]; then
  main menu
else
  main "${1:-}"
fi
