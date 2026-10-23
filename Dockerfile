FROM ubuntu:24.04

# Avoid prompts for time zone
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris

# Fix issue with libGL on Windows
ENV LIBGL_ALWAYS_INDIRECT=1

# Set by buildx (amd64 or arm64), default to amd64 for plain docker build
ARG TARGETARCH=amd64

ARG OCAML_VERSION=4.14.2
ARG FRAMAC_VERSION=33.0
ARG METACSL_VERSION=0.11
ARG WHY3_VERSION=1.8.2
ARG ALTERGO_VERSION=2.6.4
# Z3 and CVC5 versions supported by Why3 1.8.2
ARG Z3_VERSION=4.13.4
ARG CVC5_VERSION=1.2.1
# Ivette (the Frama-C GUI) requires Node 24 and Yarn
ARG NODE_VERSION=24.22.1

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y x11-apps xdg-utils wget curl unzip xz-utils nano \
	git make gcc g++ m4 pkg-config bubblewrap rsync opam \
	libgmp-dev zlib1g-dev libyaml-dev graphviz \
	libgtk-3-dev libgtksourceview-3.0-dev libexpat1-dev

# Libraries needed by Ivette (Electron application)
RUN apt-get install -y libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 \
	libdrm2 libgbm1 libasound2t64 libxkbcommon0 libxcomposite1 libxdamage1 \
	libxrandr2 libxss1 libxtst6 libsecret-1-0 libnotify4 libgl1 libegl1 \
	fonts-dejavu-core yaru-theme-icon

# Install Z3
RUN case ${TARGETARCH} in amd64) z3arch=x64-glibc-2.35 ;; arm64) z3arch=arm64-glibc-2.34 ;; esac \
	&& wget -q https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/z3-${Z3_VERSION}-${z3arch}.zip \
	&& unzip -q z3-${Z3_VERSION}-${z3arch}.zip \
	&& install z3-${Z3_VERSION}-${z3arch}/bin/z3 /usr/local/bin/z3 \
	&& rm -rf z3-*

# Install CVC5
RUN case ${TARGETARCH} in amd64) cvc5arch=x86_64 ;; arm64) cvc5arch=arm64 ;; esac \
	&& wget -q https://github.com/cvc5/cvc5/releases/download/cvc5-${CVC5_VERSION}/cvc5-Linux-${cvc5arch}-static.zip \
	&& unzip -q cvc5-Linux-${cvc5arch}-static.zip \
	&& install cvc5-Linux-${cvc5arch}-static/bin/cvc5 /usr/local/bin/cvc5 \
	&& rm -rf cvc5-*

# Install Node and Yarn (for building Ivette)
RUN case ${TARGETARCH} in amd64) nodearch=x64 ;; arm64) nodearch=arm64 ;; esac \
	&& wget -q https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${nodearch}.tar.xz \
	&& tar xJf node-v${NODE_VERSION}-linux-${nodearch}.tar.xz -C /usr/local --strip-components=1 \
	&& rm node-v${NODE_VERSION}-linux-${nodearch}.tar.xz \
	&& npm install --global yarn

# Install OCaml with opam, in a location readable by all users
ENV OPAMROOT=/opt/opam
ENV OPAMYES=1
ENV OPAMCONFIRMLEVEL=unsafe-yes
RUN opam init --disable-sandboxing --bare \
	&& opam switch create default ${OCAML_VERSION} \
	&& opam clean -a -c -s --logs
ENV OPAM_SWITCH_PREFIX=/opt/opam/default
ENV PATH=/opt/opam/default/bin:$PATH

# Install Why3 (with its IDE), Alt-Ergo, Frama-C and MetAcsl
RUN opam install lablgtk3 lablgtk3-sourceview3 \
	alt-ergo.${ALTERGO_VERSION} why3.${WHY3_VERSION} why3-ide.${WHY3_VERSION} \
	frama-c.${FRAMAC_VERSION} frama-c-metacsl.${METACSL_VERSION} \
	&& opam clean -a -c -s --logs

# Build and install Ivette now (as done by 'frama-c-gui' on its first run)
# so that the GUI works offline
RUN tmp=$(mktemp -d) && cd $tmp \
	&& tar zxf ${OPAM_SWITCH_PREFIX}/lib/frama-c/ivette.tgz \
	&& cd ivette \
	&& make dist \
	&& make PREFIX=${OPAM_SWITCH_PREFIX} install \
	&& cd / && rm -rf $tmp ${OPAM_SWITCH_PREFIX}/lib/frama-c/ivette.tgz \
	&& yarn cache clean && rm -rf /root/.cache /root/.npm

# Detect provers (the configuration in /root is copied to the home
# directory of the user created by startup.sh)
RUN why3 config detect

# Keep the opam binaries in the PATH after 'su' in startup.sh
RUN sed -i 's|^PATH="|PATH="/opt/opam/default/bin:|' /etc/environment

# The Chromium sandbox of Electron cannot run in a container: wrap Ivette to disable it
RUN rm ${OPAM_SWITCH_PREFIX}/bin/frama-c-gui \
	&& printf '#!/bin/sh\nexec %s/lib/frama-c/ivette/frama-c-gui --no-sandbox "$@"\n' \
	   ${OPAM_SWITCH_PREFIX} > ${OPAM_SWITCH_PREFIX}/bin/frama-c-gui \
	&& chmod 755 ${OPAM_SWITCH_PREFIX}/bin/frama-c-gui

# VNC server, XFCE desktop and noVNC to use the GUIs from a web browser
RUN apt-get update && apt-get install -y --no-install-recommends \
	tigervnc-standalone-server novnc python3-websockify \
	xfce4 xfce4-terminal dbus-x11 adwaita-icon-theme elementary-xfce-icon-theme \
	&& update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper \
	&& sed -i 's/^TerminalEmulator=.*/TerminalEmulator=xfce4-terminal/' /etc/xdg/xfce4/helpers.rc
EXPOSE 6080

# Desktop shortcuts (/root is the skeleton of the home of the user)
RUN mkdir -p /root/Desktop \
	&& printf '[Desktop Entry]\nType=Application\nName=Frama-C GUI\nExec=frama-c-gui\nIcon=applications-development\nPath=/workspace\nTerminal=false\n' \
	   > /root/Desktop/frama-c-gui.desktop \
	&& printf '[Desktop Entry]\nType=Application\nName=Why3 IDE\nExec=why3 ide\nIcon=applications-science\nPath=/workspace\nTerminal=false\n' \
	   > /root/Desktop/why3-ide.desktop \
	&& printf '[Desktop Entry]\nType=Application\nName=Terminal\nExec=xfce4-terminal --working-directory=/workspace\nIcon=utilities-terminal\nTerminal=false\n' \
	   > /root/Desktop/terminal.desktop \
	&& chmod 755 /root/Desktop/*.desktop

RUN apt-get autoremove -y && apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN userdel --remove ubuntu 2>/dev/null; \
	useradd --create-home --skel /root --shell /bin/bash --user-group ubuntu \
	&& echo "ubuntu:ubuntu" | chpasswd

RUN rm -rf /tmp/*

COPY startup.sh /
ENTRYPOINT ["/startup.sh"]
