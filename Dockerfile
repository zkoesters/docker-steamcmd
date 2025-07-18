FROM debian:bookworm-slim@sha256:6ac2c08566499cc2415926653cf2ed7c3aedac445675a013cc09469c9e118fdd AS build_stage

ARG DEBIAN_FRONTEND="noninteractive"
ARG PUID=1000

ENV USER=steam
ENV HOME_PATH="/home/${USER}"
ENV STEAMCMD_PATH="${HOME_PATH}/steamcmd"
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAMCMD_PATH"

ADD --chmod=644 https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz /tmp/steamcmd_linux.tar.gz

RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
	    ca-certificates=20230311 \
	    dbus=1.14.10-1~deb12u1 \
	    lib32gcc-s1=12.2.0-14+deb12u1 \
		lib32stdc++6=12.2.0-14+deb12u1 \
		locales=2.36-9+deb12u10 \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	&& useradd -u "${PUID}" -m "${USER}" \
	&& su "${USER}" -c \
		"mkdir -p \"${STEAMCMD_PATH}\" \
                && tar xvzf /tmp/steamcmd_linux.tar.gz -C \"${STEAMCMD_PATH}\" \
                && \"./${STEAMCMD_PATH}/steamcmd.sh\" +quit \
                && ln -s \"${STEAMCMD_PATH}/linux32/steamclient.so\" \"${STEAMCMD_PATH}/steamservice.so\" \
                && mkdir -p \"${HOME_PATH}/.steam/sdk32\" \
                && ln -s \"${STEAMCMD_PATH}/linux32/steamclient.so\" \"${HOME_PATH}/.steam/sdk32/steamclient.so\" \
                && ln -s \"${STEAMCMD_PATH}/linux32/steamcmd\" \"${STEAMCMD_PATH}/linux32/steam\" \
                && mkdir -p \"${HOME_PATH}/.steam/sdk64\" \
                && ln -s \"${STEAMCMD_PATH}/linux64/steamclient.so\" \"${HOME_PATH}/.steam/sdk64/steamclient.so\" \
                && ln -s \"${STEAMCMD_PATH}/linux64/steamcmd\" \"${STEAMCMD_PATH}/linux64/steam\" \
                && ln -s \"${STEAMCMD_PATH}/steamcmd.sh\" \"${STEAMCMD_PATH}/steam.sh\"" \
 	&& ln -s "${STEAMCMD_PATH}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so" \
 	&& rm -f /etc/machine-id \
    && dbus-uuidgen --ensure=/etc/machine-id \
    && apt-get purge -y --auto-remove dbus \
 	&& rm -f /tmp/steamcmd_linux.tar.gz \
	&& rm -rf /var/lib/apt/lists/*

FROM build_stage AS bookworm-root
WORKDIR ${STEAMCMD_PATH}

FROM bookworm-root AS bookworm
USER ${USER}

FROM bookworm-root AS build_stage_wine

ARG DEBIAN_FRONTEND="noninteractive"
ARG WINE_BRANCH=devel
ARG WINE_VERSION=10.5~bookworm-1
ARG WINE_MONO_VERSION=10.0.0

ADD https://dl.winehq.org/wine-builds/winehq.key /tmp/winehq-archive.key
ADD --chmod=644 https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources /tmp/winehq-bookworm.sources
ADD https://dl.winehq.org/wine/wine-mono/${WINE_MONO_VERSION}/wine-mono-${WINE_MONO_VERSION}-x86.tar.xz /tmp/wine-mono-${WINE_MONO_VERSION}-x86.tar.xz

RUN dpkg --add-architecture i386 \
	&& mkdir -pm755 /etc/apt/keyrings \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        gnupg=2.2.40-1.1 \
    && gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key /tmp/winehq-archive.key \
    && mv /tmp/winehq-bookworm.sources /etc/apt/sources.list.d/winehq-bookworm.sources \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        libvulkan1=1.3.239.0-1 \
		winbind=2:4.17.12+dfsg-0+deb12u1 \
		xvfb=2:21.1.7-3+deb12u9 \
		xz-utils=5.4.1-1 \
	&& apt-get install -y --install-recommends \
	    wine-${WINE_BRANCH}-amd64=${WINE_VERSION} \
		wine-${WINE_BRANCH}-i386=${WINE_VERSION} \
		wine-${WINE_BRANCH}=${WINE_VERSION} \
		winehq-${WINE_BRANCH}=${WINE_VERSION} \
	&& mkdir -p /opt/wine/mono \
	&& tar -xf /tmp/wine-mono-${WINE_MONO_VERSION}-x86.tar.xz -C /opt/wine/mono \
	&& apt-get purge -y --auto-remove gnupg \
	&& rm /tmp/winehq-archive.key \
	&& rm /tmp/wine-mono-${WINE_MONO_VERSION}-x86.tar.xz \
    && rm -rf /var/lib/apt/lists/*

FROM build_stage_wine AS bookworm-wine-root
WORKDIR ${STEAMCMD_PATH}

FROM bookworm-wine-root AS bookworm-wine
USER ${USER}

FROM bookworm-root AS build_stage_proton

ARG DEBIAN_FRONTEND="noninteractive"
ARG PROTON_GE_VERSION=10-4

ADD --chmod=644 https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${PROTON_GE_VERSION}/GE-Proton${PROTON_GE_VERSION}.tar.gz /tmp/GE-Proton${PROTON_GE_VERSION}.tar.gz

RUN dpkg --add-architecture i386 \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        libvulkan1=1.3.239.0-1 \
		winbind=2:4.17.12+dfsg-0+deb12u1 \
		xvfb=2:21.1.7-3+deb12u9 \
		xz-utils=5.4.1-1 \
	&& su "${USER}" -c \
	    "mkdir -p \"${STEAMCMD_PATH}/compatibilitytools.d\" \
	        && mkdir -p \"${HOME_PATH}/.config/protonfixes\" \
	        && tar xvzf /tmp/GE-Proton${PROTON_GE_VERSION}.tar.gz -C \"${STEAMCMD_PATH}/compatibilitytools.d\"" \
	&& rm /tmp/GE-Proton${PROTON_GE_VERSION}.tar.gz \
    && rm -rf /var/lib/apt/lists/*

FROM build_stage_proton AS bookworm-proton-root
WORKDIR ${STEAMCMD_PATH}

FROM bookworm-proton-root AS bookworm-proton
USER ${USER}
