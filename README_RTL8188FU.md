# RTL8188FU WiFi Driver para dArkOS

Suporte para adaptadores WiFi USB **Realtek RTL8188FTV** (VID:0bda PID:f179) no dArkOS.

---

## 🚀 Instalação Rápida (3 passos)

### 1️⃣ No seu PC (WSL/Linux):

```bash
cd /home/user/dArkOS_experiments
./build_rtl8188fu_standalone.sh
```

Isso cria: `rtl8188fu_install_package.tar.gz`

### 2️⃣ Copiar para o R36S:

Copie `rtl8188fu_install_package.tar.gz` para **`/roms/tools/`** no cartão SD

### 3️⃣ No R36S:

**Método A - Menu Tools (Recomendado):**
- EmulationStation → Tools → **"Install RTL8188FU WiFi Driver"**
- Siga as instruções na tela

**Método B - Terminal SSH:**
```bash
cd /roms/tools/
tar xzf rtl8188fu_install_package.tar.gz
cd rtl8188fu_install_package
sudo ./install.sh
```

**Pronto!** Conecte o adaptador WiFi e use. 📡

---

## 🆕 Compilar Nova Imagem

Se preferir compilar uma imagem nova do zero com o driver incluído:

```bash
# Para R36S (RGB30):
./build_rgb30.sh

# Para outros dispositivos RK3566:
./build_rg353m.sh   # RG353M
./build_rg353v.sh   # RG353V
./build_rg503.sh    # RG503
./build_rgb20pro.sh # RGB20Pro
```

O driver RTL8188FU será compilado e incluído automaticamente.

---

## 📚 Documentação Completa

Para instruções detalhadas, troubleshooting e opções avançadas, veja:
**[RTL8188FU_INSTALL_GUIDE.md](RTL8188FU_INSTALL_GUIDE.md)**

---

## ✅ Verificar Instalação

```bash
# Ver se o driver está carregado:
lsmod | grep rtl8188fu

# Ver o dispositivo USB:
lsusb | grep 0bda:f179

# Ver interface WiFi:
ip link show
```

---

## 📝 Arquivos Incluídos

| Arquivo | Descrição |
|---------|-----------|
| `build_rtl8188fu.sh` | Compila driver durante build da imagem |
| `build_rtl8188fu_standalone.sh` | Cria pacote para instalação em imagem existente |
| `install_rtl8188fu_on_device.sh` | Compila e instala direto no R36S (requer kernel headers) |
| `dArkOS_Tools/Install RTL8188FU WiFi Driver.sh` | Script para menu Tools do EmulationStation |
| `RTL8188FU_INSTALL_GUIDE.md` | Guia completo de instalação em português |
| `README_RTL8188FU.md` | Este arquivo - guia rápido |

---

## 🎯 Dispositivos Suportados

- ✅ RGB30 (R36S)
- ✅ RGB20Pro
- ✅ RG353M
- ✅ RG353V
- ✅ RG503

Todos os dispositivos RK3566.

---

## 🐛 Problemas?

1. **WiFi não aparece**: Reconecte o adaptador USB
2. **Driver não carrega**: Verifique com `dmesg | grep rtl8188fu`
3. **Kernel incompatível**: Recompile o pacote com kernel atualizado

Veja o guia completo para mais troubleshooting.

---

**Desenvolvido para dArkOS** 🎮
