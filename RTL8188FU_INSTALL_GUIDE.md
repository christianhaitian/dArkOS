# Guia de Instalação do Driver RTL8188FU para dArkOS Existente

Se você já tem o dArkOS instalado no seu R36S e quer adicionar suporte para o adaptador WiFi USB **Realtek RTL8188FTV** (VID:0bda PID:f179), existem três opções:

## 📦 Opção 1: Pacote Pré-Compilado (MAIS FÁCIL)

### Passo 1: Compilar o pacote no seu PC

No seu PC Linux (ou WSL) com o repositório dArkOS:

```bash
cd /home/user/dArkOS_experiments
./build_rtl8188fu_standalone.sh
```

Isso vai gerar o arquivo: **`rtl8188fu_install_package.tar.gz`**

### Passo 2: Transferir para o R36S

Transfira o arquivo `rtl8188fu_install_package.tar.gz` para o seu R36S usando:
- **SSH/SFTP**: Se você tiver WiFi temporário ou cabo ethernet
- **Cartão SD**: Copie o arquivo para `/roms/tools/` ou qualquer pasta acessível
- **USB**: Monte um pendrive e copie

### Passo 3: Instalar no R36S

No R36S, abra um terminal e execute:

```bash
cd /caminho/onde/voce/copiou
tar xzf rtl8188fu_install_package.tar.gz
cd rtl8188fu_install_package
sudo ./install.sh
```

### Passo 4: Conectar o adaptador

Conecte o adaptador USB WiFi. O driver deve carregar automaticamente!

Verifique com:
```bash
lsmod | grep rtl8188fu
```

---

## 🔧 Opção 2: Compilar Direto no R36S (REQUER HEADERS DO KERNEL)

**Atenção**: Esta opção só funciona se você tiver os headers do kernel instalados no R36S (improvável em builds padrão).

### Transferir o script

Copie o arquivo `install_rtl8188fu_on_device.sh` para o R36S.

### Executar no R36S

```bash
chmod +x install_rtl8188fu_on_device.sh
sudo ./install_rtl8188fu_on_device.sh
```

O script vai:
1. Verificar se tem headers do kernel
2. Baixar o código fonte do driver
3. Compilar no próprio dispositivo
4. Instalar automaticamente

---

## 🛠️ Opção 3: Instalação Manual (PARA USUÁRIOS AVANÇADOS)

Se você já tem o módulo `rtl8188fu.ko` compilado:

### 1. Copiar o módulo do kernel

```bash
sudo mkdir -p /lib/modules/$(uname -r)/kernel/drivers/net/wireless/realtek/rtl8188fu
sudo cp rtl8188fu.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/realtek/rtl8188fu/
sudo chmod 644 /lib/modules/$(uname -r)/kernel/drivers/net/wireless/realtek/rtl8188fu/rtl8188fu.ko
```

### 2. Atualizar dependências

```bash
sudo depmod -a
```

### 3. Configurar o driver

```bash
echo "options rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0" | sudo tee /etc/modprobe.d/rtl8188fu.conf
```

### 4. Adicionar regras udev

Edite `/etc/udev/rules.d/40-usb_modeswitch.rules` e adicione antes da linha `LABEL="end_modeswitch"`:

```
# Realtek RTL8188FTV/RTL8188FU 802.11n USB WiFi Adapter
#   Direct WiFi mode, no mode switching needed
ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="f179"
```

### 5. Recarregar regras udev

```bash
sudo udevadm control --reload-rules
```

### 6. Carregar o módulo

```bash
sudo modprobe rtl8188fu
```

---

## ✅ Verificação

Após a instalação, verifique se funcionou:

### Verificar se o driver carregou

```bash
lsmod | grep rtl8188fu
```

Deve mostrar algo como:
```
rtl8188fu             1234567  0
```

### Verificar o dispositivo USB

```bash
lsusb | grep 0bda:f179
```

Deve mostrar:
```
Bus 001 Device 004: ID 0bda:f179 Realtek Semiconductor Corp.
```

### Verificar a interface WiFi

```bash
ip link show
```

ou

```bash
iwconfig
```

Deve aparecer uma interface `wlan0` ou similar.

### Ver logs do kernel

```bash
dmesg | grep rtl8188fu
```

---

## 🐛 Resolução de Problemas

### WiFi não aparece

1. **Reconectar o adaptador USB**
   ```bash
   # Desconecte fisicamente e reconecte
   ```

2. **Carregar o módulo manualmente**
   ```bash
   sudo modprobe rtl8188fu
   ```

3. **Verificar se o USB foi detectado**
   ```bash
   lsusb
   dmesg | tail -20
   ```

### Driver não carrega

1. **Verificar mensagens de erro**
   ```bash
   dmesg | grep -i error
   dmesg | grep rtl
   ```

2. **Verificar versão do kernel**
   ```bash
   uname -r
   ```

   O módulo deve ser compilado para a mesma versão do kernel!

### Interface WiFi não funciona

1. **Reiniciar NetworkManager**
   ```bash
   sudo systemctl restart NetworkManager
   ```

2. **Desbloquear WiFi (se estiver bloqueado)**
   ```bash
   sudo rfkill unblock wlan
   ```

3. **Verificar status do NetworkManager**
   ```bash
   nmcli device status
   ```

---

## 🗑️ Desinstalar

Para remover o driver:

```bash
# Descarregar o módulo
sudo modprobe -r rtl8188fu

# Remover arquivos
sudo rm /lib/modules/$(uname -r)/kernel/drivers/net/wireless/realtek/rtl8188fu/rtl8188fu.ko
sudo rm /etc/modprobe.d/rtl8188fu.conf
sudo depmod -a

# Remover regra udev (edite o arquivo manualmente)
sudo nano /etc/udev/rules.d/40-usb_modeswitch.rules
# Remova as linhas do RTL8188FU

# Recarregar udev
sudo udevadm control --reload-rules
```

---

## 📝 Notas

- O módulo será carregado automaticamente quando você conectar o adaptador USB
- As configurações persistem após reiniciar
- O driver funciona com WPA2 e WPA3
- Power management está desabilitado para evitar problemas de desconexão

---

## 🆘 Suporte

Se tiver problemas:

1. Verifique que o adaptador é realmente um RTL8188FU (0bda:f179)
2. Certifique-se que a versão do kernel do módulo compilado é a mesma do sistema
3. Verifique os logs do kernel: `dmesg | grep rtl8188fu`
4. Teste em outro dispositivo Linux para confirmar que o adaptador funciona

---

**Boa sorte! 🎮📡**
