# Big Screen Monitor Display

Daemon Linux que transforma um displayzinho USB (porta-retrato digital AX206 ou Turing Smart Screen) em um painel de monitoramento de hardware — CPU, RAM, swap, disco, rede, GPU, temperaturas, processos e uptime — renderizado nativamente em Python, sem AIDA64, sem Windows e sem software proprietário.

> Pensado para quem não larga o `htop` nem o `gkrellm` e quer ver o que está acontecendo na máquina sem precisar olhar uma overlay no monitor principal.

---

## Hardware suportado

| Driver | Dispositivo | Detecção | Resolução |
|---|---|---|---|
| `AX206_DPF` | Porta-retratos digitais com chip AX206 | USB SCSI — VID `0x1908` / PID `0x0102` | 320×240, 480×320 (auto) |
| `TuringSmartScreen` | Turing Smart Screen 3.5" / 5" / 8.8" e clones QinHeng | USB-CDC serial — VID `0x1A86` / PID `0x5722` | 320×480, 480×800, 600×1024 (auto via comando `HELLO`) |

A detecção é automática (`model: auto`) — Turing serial é tentado primeiro, AX206 USB depois. Também é possível forçar o modelo via configuração.

---

## Funcionalidades

- **Coleta em background** com thread dedicada (`psutil`, leitura direta de `/sys/class/drm` para GPU AMD, `acpi/platform_profile` ou `powerprofilesctl` para perfil de energia).
- **3 layouts**: `landscape`, `portrait` (rotação 90°) e `gkrellm` (retrô, fósforo verde).
- **5 temas**: `dark`, `light`, `neon`, `cyberpunk`, `gkrellm` — este último com 3 sub-temas (`urlicht`, `classic`, `cyber_red`) e toggles individuais para cada widget.
- **Histórico em sparkline** para CPU, RAM, GPU, VRAM, disco I/O e rede RX/TX (janela de 30 amostras).
- **Logo da distro** carregado automaticamente de `/usr/share/pixmaps/$LOGO.{png,svg}` via `rsvg-convert`.
- **Otimização de banda USB no Turing**: dirty-rectangle por tiles de 48×20px com merge horizontal e shuffle de ordem para evitar tearing visível. Frames idênticos não são enviados.
- **Conversão RGB565** vetorizada via `numpy`.
- **Marquee** automático para nomes de kernel/GPU que não cabem na largura.
- **Bandeja do sistema** opcional (`pystray`) com atalho para abrir o `config_gui.py` — só ativa se houver `$DISPLAY` e o processo não rodar como root.
- **Hot-reload** das configurações: alterações em `settings.json` (brilho, orientação) são aplicadas em até 5 segundos sem reiniciar o serviço.

---

## Dependências

### Sistema (Arch / BigLinux / Manjaro)

```bash
sudo pacman -S python python-pip librsvg lm_sensors
# opcionais — só se quiser o GUI de configuração:
sudo pacman -S gtk4 libadwaita python-gobject
```

### Sistema (Debian / Ubuntu)

```bash
sudo apt install python3 python3-venv librsvg2-bin lm-sensors
# opcionais — para o GUI:
sudo apt install libgtk-4-1 libadwaita-1-0 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
```

### Python (instalado via `requirements.txt`)

- `pillow` — renderização da imagem
- `psutil` — coleta de estatísticas
- `pyusb` — driver AX206
- `pyserial` — driver Turing
- `numpy` — conversão RGB565 e dirty-rect

---

## Instalação e execução

```bash
make install   # cria .venv com Python 3.12 e instala requirements
make run       # roda o daemon em foreground
make clean     # remove o .venv
```

Para executar manualmente:

```bash
.venv/bin/python main.py        # daemon principal
.venv/bin/python config_gui.py  # janela de configurações (GTK4)
```

### Permissões USB

O acesso direto ao dispositivo USB exige uma regra `udev` ou execução como root. Exemplo de regra para o AX206:

```
# /etc/udev/rules.d/99-big-screen-monitor.rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="1908", ATTRS{idProduct}=="0102", MODE="0666"
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="5722", MODE="0666"
```

Recarregue com `sudo udevadm control --reload && sudo udevadm trigger`.

---

## Configuração

O arquivo é criado/lido em `~/.config/big-screen-monitor/settings.json`. Exemplo:

```json
{
  "model": "auto",
  "size": "3.5",
  "orientation": "horizontal",
  "brightness": 70,
  "theme": "dark",
  "network_iface": "auto",
  "gk_theme_color": "urlicht",
  "gk_show_cpu": true,
  "gk_show_proc": true,
  "gk_show_gpu": true
}
```

| Chave | Valores | Padrão |
|---|---|---|
| `model` | `auto`, `ax206`, `turing` | `auto` |
| `size` | `3.5`, `5`, `8.8`, `2.1` | `3.5` |
| `orientation` | `horizontal`, `vertical` | `horizontal` |
| `brightness` | 10–100 (mapeado para o hardware) | `70` |
| `theme` | `dark`, `light`, `neon`, `cyberpunk`, `gkrellm` | `dark` |
| `network_iface` | `auto`, `eth`, `wifi` | `auto` |
| `gk_theme_color` | `urlicht`, `classic`, `cyber_red` (só `gkrellm`) | `urlicht` |
| `gk_show_*` | toggles por widget no tema gkrellm | (vários) |

A janela GTK4 (`config_gui.py`) cobre todos esses campos e ainda gerencia `systemctl enable/disable/restart big-screen-monitor-display.service` via `pkexec` quando necessário.

---

## Arquitetura

```
┌──────────────────────────────────────────────────────────┐
│  main.py                                                 │
│  ┌────────────────┐    ┌─────────────────────────┐       │
│  │ monitor_thread │───▶│ SYSTEM_STATS (lock)     │       │
│  │ (psutil/sysfs) │    └────────┬────────────────┘       │
│  └────────────────┘             │                        │
│                                 ▼                        │
│                        render_dashboard()                │
│                  ┌──────────┬──────────┬──────────┐      │
│                  │ landscape│ portrait │ gkrellm  │      │
│                  └─────┬────┴────┬─────┴─────┬────┘      │
│                        └────────┬┴───────────┘           │
│                                 ▼                        │
│                          PIL.Image (RGB)                 │
│                                 │                        │
│            ┌────────────────────┴──────────────────┐     │
│            ▼                                       ▼     │
│     AX206_DPF.draw()                  TuringSmartScreen  │
│     (SCSI USB BULK)                   .draw()            │
│                                       (CDC serial,       │
│                                        dirty-rect tiles) │
└──────────────────────────────────────────────────────────┘
```

- **Loop principal**: renderiza um frame, envia ao display, dorme 10ms se algo mudou ou 250ms se o frame foi idêntico ao anterior. Recarrega `settings.json` a cada 5s.
- **Cache de ícones SVG** (`ICON_CACHE`) e **cache de logos da distro** (`_LOGO_CACHE`) evitam chamar `rsvg-convert` repetidamente.

---

## Estrutura do repositório

```
.
├── main.py            # daemon principal (drivers + render + loop)
├── config_gui.py      # janela GTK4/libadwaita
├── Makefile           # install / run / clean (virtualenv)
├── requirements.txt   # dependências Python
├── fonts/             # DejaVu Sans (Regular + Bold)
└── img/               # ícones simbólicos SVG (cpu, ram, gpu, etc.)
```

---

## Créditos

- **Rafael Ruscher** — autor original
- **BigLinux Team** — manutenção
- O driver Turing é baseado no trabalho de [@mathoudebine](https://github.com/mathoudebine) (`turing-smart-screen-python`, GPL-3.0)

## Licença

GPL-3.0 — veja o cabeçalho de `main.py` (`TuringSmartScreen`) e o `AboutWindow` em `config_gui.py`.

Upstream: <https://github.com/biglinux/big-screen-monitor-display>
