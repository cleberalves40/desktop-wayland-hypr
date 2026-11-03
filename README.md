# desktop-wayland-hypr

Bootstrap de uma sessão Wayland para FreeBSD com Hyprland como compositor e
Quickshell como shell QML. O projeto instala uma base configurável; não altera
o gerenciador de login existente nem substitui uma configuração de usuário.

## Instalação

Use uma conta FreeBSD já criada e execute a partir do checkout:

```sh
sudo sh ./install.sh --user cleber --browser firefox --dry-run
sudo sh ./install.sh --user cleber --browser firefox
```

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