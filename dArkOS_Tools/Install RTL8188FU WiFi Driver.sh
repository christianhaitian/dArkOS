#!/bin/bash

# RTL8188FU WiFi Driver Installer for EmulationStation Tools Menu
# This script provides a user-friendly interface for installing the WiFi driver
# Place this in /opt/system/Tools/ or use dArkOS_Tools folder

clear

PACKAGE_DIR="/roms/tools/rtl8188fu_install_package"
PACKAGE_TAR="/roms/tools/rtl8188fu_install_package.tar.gz"
SCRIPT_NAME="Install RTL8188FU WiFi Driver"

# Check if dialog is available, fallback to basic prompts
if command -v dialog &> /dev/null; then
    USE_DIALOG=1
else
    USE_DIALOG=0
fi

show_message() {
    local title="$1"
    local message="$2"
    if [ $USE_DIALOG -eq 1 ]; then
        dialog --title "$title" --msgbox "$message" 12 60
    else
        echo "=== $title ==="
        echo "$message"
        echo ""
        read -p "Pressione ENTER para continuar..."
    fi
}

show_yesno() {
    local title="$1"
    local message="$2"
    if [ $USE_DIALOG -eq 1 ]; then
        dialog --title "$title" --yesno "$message" 10 60
        return $?
    else
        echo "=== $title ==="
        echo "$message"
        read -p "Continuar? (s/n): " response
        [[ "$response" =~ ^[Ss]$ ]] && return 0 || return 1
    fi
}

show_infobox() {
    local message="$1"
    if [ $USE_DIALOG -eq 1 ]; then
        dialog --infobox "$message" 5 50
        sleep 2
    else
        echo "$message"
    fi
}

# Welcome screen
if ! show_yesno "$SCRIPT_NAME" "Este script instala o driver para adaptadores WiFi USB Realtek RTL8188FU (VID:0bda PID:f179).\n\nVocê precisa ter:\n1. O arquivo rtl8188fu_install_package.tar.gz em /roms/tools/\n2. Permissão de root (será solicitada)\n\nDeseja continuar?"; then
    clear
    exit 0
fi

# Check if package tarball exists
if [ ! -f "$PACKAGE_TAR" ]; then
    show_message "Erro - Pacote não encontrado" "O arquivo rtl8188fu_install_package.tar.gz não foi encontrado em /roms/tools/\n\nPor favor:\n1. Compile o pacote no seu PC usando:\n   ./build_rtl8188fu_standalone.sh\n\n2. Copie o arquivo .tar.gz para /roms/tools/\n\n3. Execute este script novamente."
    clear
    exit 1
fi

# Check if package is already extracted
if [ -d "$PACKAGE_DIR" ]; then
    if show_yesno "Pacote já existe" "O pacote já foi descompactado anteriormente.\n\nDeseja usar o pacote existente ou extrair novamente?"; then
        show_infobox "Usando pacote existente..."
    else
        show_infobox "Extraindo novamente..."
        rm -rf "$PACKAGE_DIR"
        cd /roms/tools/
        tar xzf rtl8188fu_install_package.tar.gz 2>&1
        if [ $? -ne 0 ]; then
            show_message "Erro" "Falha ao extrair o pacote!"
            clear
            exit 1
        fi
    fi
else
    show_infobox "Extraindo pacote..."
    cd /roms/tools/
    tar xzf rtl8188fu_install_package.tar.gz 2>&1
    if [ $? -ne 0 ]; then
        show_message "Erro" "Falha ao extrair o pacote!"
        clear
        exit 1
    fi
fi

# Verify extraction
if [ ! -d "$PACKAGE_DIR" ] || [ ! -f "$PACKAGE_DIR/install.sh" ]; then
    show_message "Erro" "Pacote extraído, mas arquivo install.sh não encontrado!"
    clear
    exit 1
fi

# Run installation
cd "$PACKAGE_DIR"

if [ $USE_DIALOG -eq 1 ]; then
    # Run with dialog progress
    {
        echo "0"
        echo "# Iniciando instalação..."
        sleep 1

        echo "25"
        echo "# Instalando módulo do kernel..."
        sudo ./install.sh > /tmp/wifi_install.log 2>&1
        INSTALL_RESULT=$?

        echo "75"
        echo "# Finalizando..."
        sleep 1

        echo "100"
        echo "# Concluído!"
        sleep 1
    } | dialog --title "Instalando Driver RTL8188FU" --gauge "Preparando..." 7 60 0

    if [ $INSTALL_RESULT -eq 0 ]; then
        # Show installation log
        dialog --title "Log de Instalação" --textbox /tmp/wifi_install.log 20 70

        # Check if driver loaded
        if lsmod | grep -q rtl8188fu; then
            show_message "Sucesso!" "Driver RTL8188FU instalado com sucesso!\n\nO driver está carregado e pronto para uso.\n\nConecte seu adaptador WiFi USB agora e use o menu WiFi do dArkOS para conectar."
        else
            show_message "Instalação Completa" "Driver RTL8188FU instalado com sucesso!\n\nO driver será carregado quando você conectar o adaptador WiFi USB.\n\nConecte o adaptador e use o menu WiFi do dArkOS para conectar.\n\nPara verificar: Menu > Tools > WiFi"
        fi
    else
        show_message "Erro na Instalação" "Houve um erro durante a instalação.\n\nVerifique o log em /tmp/wifi_install.log\n\nPossíveis causas:\n- Versão do kernel incompatível\n- Falta de permissões\n- Driver já instalado"
    fi
else
    # Run without dialog
    echo "=== Instalando Driver RTL8188FU ==="
    echo ""
    sudo ./install.sh
    INSTALL_RESULT=$?
    echo ""

    if [ $INSTALL_RESULT -eq 0 ]; then
        if lsmod | grep -q rtl8188fu; then
            echo "✓ Sucesso! Driver instalado e carregado."
        else
            echo "✓ Driver instalado. Será carregado ao conectar o adaptador."
        fi
    else
        echo "✗ Erro na instalação. Verifique as mensagens acima."
    fi

    read -p "Pressione ENTER para sair..."
fi

clear
exit 0
