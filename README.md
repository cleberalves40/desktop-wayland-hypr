# desktop-wayland-hypr

Bootstrap de uma sessão Wayland para FreeBSD com Hyprland como compositor e
Quickshell como shell QML. O projeto instala uma base configurável; não altera
o gerenciador de login existente nem substitui uma configuração de usuário.
Versão atual: `0.3.0` (SemVer; fonte da versão em `VERSION`).

## Instalação

Use uma conta FreeBSD já criada e execute a partir do checkout:

```sh
sudo sh ./install.sh --user cleber --browser firefox --dry-run
sudo sh ./install.sh --user cleber --browser firefox
```

Consulte a versão com `sh ./install.sh --version`.

`--browser` aceita `none`, `firefox`, `chromium` ou `both`; por padrão, nenhum
navegador é escolhido. `--widevine` seleciona Chromium e instala `foreign-cdm`:

```sh
sudo sh ./install.sh --user cleber --widevine --dry-run
```

O instalador exige FreeBSD, root para alterações reais e uma conta existente.
Ele habilita e inicia D-Bus e seatd, adiciona a conta aos grupos `video` e
`seatd` se esses grupos existirem e ainda não forem membros, e instala os
arquivos iniciais em `~/.config`. Configurações já existentes são preservadas.
Depois de uma mudança de grupo, encerre e inicie a sessão novamente. Para
iniciar o ambiente manualmente a partir de um TTY:

```sh
~/.local/bin/desktop-wayland-hypr
```

O `install.sh` não habilita automaticamente Ly nem cria uma entrada de login;
primeiro valide o driver gráfico e a sessão manualmente. Os nomes de pacotes
seguem a árvore FreeBSD ports, mas disponibilidade pode variar por versão,
arquitetura e repositório configurado.

## Hardware

O perfil padrão é `--gpu intel` e `--wifi ax210`. `--gpu` aceita `intel`,
`amd` ou `nvidia`; os perfis Intel/AMD instalam `drm-kmod`, e o perfil NVIDIA
também instala `nvidia-driver` e `nvidia-drm-kmod`. O metapacote DRM seleciona
os módulos/firmware conforme a versão do FreeBSD e arquitetura disponíveis nos
repositórios. Confira as mensagens dos pacotes e reinicie antes de validar
Hyprland. `--wifi` aceita `ax210`, `legacy` ou `none`; `legacy` representa os
adaptadores Intel listados por `iwm(4)`, e não instala firmware AX210.

Em placas NVIDIA, `nvidia-drm-kmod` exige `hw.nvidiadrm.modeset=1` em
`/boot/loader.conf` antes de carregar `nvidia-drm`. O instalador não altera
configuração de boot; siga as mensagens do pacote e confirme o hardware antes
de editar esse arquivo.

O perfil AX210 instala `wifi-firmware-iwlwifi-kmod`. O driver vem do sistema
base e depende da versão do FreeBSD; o pacote de firmware não habilita Wi-Fi por
si só. `--wifi-driver` aceita `auto`, `iwlwifi`, `iwx` ou `iwm` e, quando
informado, ajusta `devmatch_blocklist` para preferir o driver escolhido,
preservando outros módulos já bloqueados. A opção explícita `auto` remove da
lista os bloqueios desses três drivers. Sem essa opção, o instalador não altera
a seleção de driver.

Para AX210, use `auto`, `iwx` ou `iwlwifi`; `iwm` não suporta esse adaptador.
Para adaptadores Intel listados por `iwm(4)`, use `--wifi legacy` com `auto` ou
`iwm`. O suporte do `iwm(4)` a modos Wi-Fi é limitado e não garante associação a
redes configuradas apenas para 802.11n/ac. `iwx(4)` lista AX210, mas não oferece
802.11ax atualmente; confirme recursos e estabilidade no FreeBSD instalado.
As interfaces Ethernet Intel 1GbE normalmente usam drivers do sistema base
(por exemplo, `em(4)` ou `igc(4)`), sem pacote adicional. Confirme o modelo com
`pciconf -lv` e a interface com `ifconfig`.

## Aplicativos e limites

A base instala Neovim-Qt, Code - OSS (`vscode` no ports, não o binário oficial
Microsoft), Inkscape, GIMP, Thunar, LibreOffice e Zathura com o backend Poppler.
Firefox e Chromium são opcionais. A seleção de navegador não presume qual
serviço de streaming será usado.

Widevine no FreeBSD é uma tentativa best-effort, não uma garantia de DRM. O
pacote `foreign-cdm` sozinho não assegura que o Chromium reconheça o CDM nem
que um serviço permita reprodução, codecs ou determinada resolução. Teste cada
serviço, GPU e monitor no equipamento alvo. Se `auto-chromium+widevine-install`
estiver instalado, `--widevine` chama esse assistente após instalar os pacotes.

O OctoPkg gráfico não está disponível como pacote oficial na árvore consultada.
`octopkg-tui` é uma aplicação de terminal, não uma GUI, e não é instalada por
este projeto. Integração com uma port ou pacote gráfico deve ser adicionada
quando a origem e o método de distribuição estiverem definidos.

## Testes

No host de desenvolvimento:

```sh
sh -n install.sh bin/start-session.sh
sh tests/smoke.sh
```

O dry-run e os testes smoke não instalam pacotes. A instalação e a sessão gráfica
precisam ser verificadas em FreeBSD real com o hardware, os drivers e os
serviços desejados; este repositório ainda não certifica essas combinações.