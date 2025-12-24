#!/usr/bin/env bash

disable_ubuntu_report() {
    ubuntu-report send no 2>/dev/null || true
    apt remove ubuntu-report -y || true
}

remove_appcrash_popup() {
    apt remove apport apport-gtk -y || true
}

remove_snaps() {
    if snap list >/dev/null 2>&1; then
        while [ "$(snap list | wc -l)" -gt 1 ]; do
            for snap in $(snap list | tail -n +2 | awk '{print $1}'); do
                snap remove --purge "$snap" 2>/dev/null || true
            done
        done
    fi
    systemctl stop snapd.socket snapd.service 2>/dev/null || true
    systemctl disable snapd.socket snapd.service 2>/dev/null || true
    systemctl mask snapd.socket snapd.service 2>/dev/null || true
    apt purge snapd -y || true
    rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd
    rm -rf /home/*/snap
    cat <<-EOF | tee /etc/apt/preferences.d/nosnap.pref
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
}

disable_terminal_ads() {
    sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news 2>/dev/null || true
    if command -v pro; then
        pro config set apt_news=false 2>/dev/null || true
    fi
}

update_system() {
    apt update && apt upgrade -y
}

cleanup() {
    apt autoremove -y && apt autoclean
}

setup_flathub() {
    apt install flatpak gnome-software-plugin-flatpak --no-install-recommends -y
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

restore_firefox() {
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list
    cat <<-EOF | tee /etc/apt/preferences.d/mozilla
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
    apt update
    apt install firefox -y
}

ask_reboot() {
    echo 'Deseja reiniciar agora? (y/n)'
    read -r choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        reboot
    fi
}

msg() {
    tput setaf 2
    echo "[*] $1"
    tput sgr0
}

error_msg() {
    tput setaf 1
    echo "[!] $1"
    tput sgr0
}

check_root_user() {
    if [ "$(id -u)" != 0 ]; then
        error_msg 'Execute o script como root (sudo)!'
        exit 1
    fi
}

print_banner() {
    echo '
    Ubuntu Debloat Simples
    By @polkaulfield (versão limpa sem temas vanilla)
    '
}

show_menu() {
    echo 'Escolha o que fazer: '
    echo '1 - Aplicar tudo (RECOMENDADO)'
    echo '2 - Desativar relatório Ubuntu'
    echo '3 - Remover popup de crash'
    echo '4 - Remover snaps e snapd'
    echo '5 - Desativar anúncios no terminal (LTS)'
    echo '6 - Instalar Flathub e GNOME Software'
    echo '7 - Instalar Firefox do repositório Mozilla'
    echo 'q - Sair'
    echo
}

main() {
    check_root_user
    while true; do
        clear
        print_banner
        show_menu
        read -p 'Sua escolha: ' choice
        case $choice in
        1)
            auto
            msg 'Tudo concluído!'
            ask_reboot
            ;;
        2) disable_ubuntu_report; msg 'Concluído!' ;;
        3) remove_appcrash_popup; msg 'Concluído!' ;;
        4) remove_snaps; msg 'Concluído!'; ask_reboot ;;
        5) disable_terminal_ads; msg 'Concluído!' ;;
        6) update_system; setup_flathub; msg 'Concluído!'; ask_reboot ;;
        7) restore_firefox; msg 'Concluído!' ;;
        q|Q) exit 0 ;;
        *) error_msg 'Opção inválida!' ;;
        esac
        echo "Pressione Enter para continuar..."
        read
    done
}

auto() {
    msg 'Atualizando sistema'
    update_system
    msg 'Desativando relatório Ubuntu'
    disable_ubuntu_report
    msg 'Removendo popup de crash'
    remove_appcrash_popup
    msg 'Desativando anúncios no terminal'
    disable_terminal_ads
    msg 'Removendo snaps'
    remove_snaps
    msg 'Configurando Flathub'
    setup_flathub
    msg 'Instalando Firefox Mozilla'
    restore_firefox
    msg 'Limpando pacotes desnecessários'
    cleanup
}

(return 2>/dev/null) || main
