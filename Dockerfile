FROM debian:trixie-slim@sha256:a347fd7510ee31a84387619a492ad6c8eb0af2f2682b916ff3e643eb076f925a AS build_stage

ARG DEBIAN_FRONTEND="noninteractive"
ARG PUID=1000

ENV USER=steam
ENV HOME_PATH="/home/${USER}"
ENV STEAMCMD_PATH="${HOME_PATH}/steamcmd"
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAMCMD_PATH"

# renovate: suite=trixie depName=ca-certificates
ENV CA_CERTIFICATES_VERSION="20250419"
# renovate: suite=trixie depName=dbus
ENV DBUS_VERSION="1.16.2-2"
# renovate: suite=trixie depName=lib32gcc-s1
ENV LIB32GCC_S1_VERSION="14.2.0-19"
# renovate: suite=trixie depName=lib32stdc++6
ENV LIB32STDCPP6_VERSION="14.2.0-19"
# renovate: suite=trixie depName=locales
ENV LOCALES_VERSION="2.41-12"

ADD --chmod=644 https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz /tmp/steamcmd_linux.tar.gz

RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
	    ca-certificates="${CA_CERTIFICATES_VERSION}" \
	    dbus="${DBUS_VERSION}" \
	    lib32gcc-s1="${LIB32GCC_S1_VERSION}" \
		lib32stdc++6="${LIB32STDCPP6_VERSION}" \
		locales="${LOCALES_VERSION}" \
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

FROM build_stage AS trixie-root
WORKDIR ${STEAMCMD_PATH}

FROM trixie-root AS trixie
USER ${USER}

FROM trixie-root AS build_stage_wine

ARG DEBIAN_FRONTEND="noninteractive"
ARG WINE_BRANCH=devel
ARG WINE_VERSION=10.10~trixie-1
ARG WINE_MONO_VERSION=10.1.0

# renovate: suite=trixie depName=gnupg
ENV GNUPG_VERSION="2.4.7-21+deb13u1"
# renovate: suite=trixie depName=libvulkan1
ENV LIBVULKAN1_VERSION="1.4.309.0-1"
# renovate: suite=trixie depName=winbind
ENV WINBIND_VERSION="2:4.22.4+dfsg-1~deb13u1"
# renovate: suite=trixie depName=xvfb
ENV XVFB_VERSION="2:21.1.16-1.3"
# renovate: suite=trixie depName=xz-utils
ENV XZ_UTILS_VERSION="5.8.1-1"

ADD https://dl.winehq.org/wine-builds/winehq.key /tmp/winehq-archive.key
ADD --chmod=644 https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources /tmp/winehq-trixie.sources
ADD https://dl.winehq.org/wine/wine-mono/${WINE_MONO_VERSION}/wine-mono-${WINE_MONO_VERSION}-x86.tar.xz /tmp/wine-mono-${WINE_MONO_VERSION}-x86.tar.xz

RUN dpkg --add-architecture i386 \
	&& mkdir -pm755 /etc/apt/keyrings \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        gnupg="${GNUPG_VERSION}" \
    && gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key /tmp/winehq-archive.key \
    && mv /tmp/winehq-trixie.sources /etc/apt/sources.list.d/winehq-trixie.sources \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        libvulkan1="${LIBVULKAN1_VERSION}" \
		winbind="${WINBIND_VERSION}" \
		xvfb="${XVFB_VERSION}" \
		xz-utils="${XZ_UTILS_VERSION}" \
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

FROM build_stage_wine AS trixie-wine-root
WORKDIR ${STEAMCMD_PATH}

FROM trixie-wine-root AS trixie-wine
USER ${USER}

FROM trixie-root AS build_stage_proton

ARG DEBIAN_FRONTEND="noninteractive"
ARG PROTON_GE_VERSION=10-15

# renovate: suite=trixie depName=libvulkan1
ENV LIBVULKAN1_VERSION="1.4.309.0-1"
# renovate: suite=trixie depName=winbind
ENV WINBIND_VERSION="2:4.22.4+dfsg-1~deb13u1"
# renovate: suite=trixie depName=xvfb
ENV XVFB_VERSION="2:21.1.16-1.3"
# renovate: suite=trixie depName=xz-utils
ENV XZ_UTILS_VERSION="5.8.1-1"

ADD --chmod=644 https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${PROTON_GE_VERSION}/GE-Proton${PROTON_GE_VERSION}.tar.gz /tmp/GE-Proton${PROTON_GE_VERSION}.tar.gz

RUN dpkg --add-architecture i386 \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        libvulkan1="${LIBVULKAN1_VERSION}" \
		winbind="${WINBIND_VERSION}" \
		xvfb="${XVFB_VERSION}" \
		xz-utils="${XZ_UTILS_VERSION}" \
	&& su "${USER}" -c \
	    "mkdir -p \"${STEAMCMD_PATH}/compatibilitytools.d\" \
	        && mkdir -p \"${HOME_PATH}/.config/protonfixes\" \
	        && tar xvzf /tmp/GE-Proton${PROTON_GE_VERSION}.tar.gz -C \"${STEAMCMD_PATH}/compatibilitytools.d\"" \
	&& rm /tmp/GE-Proton${PROTON_GE_VERSION}.tar.gz \
    && rm -rf /var/lib/apt/lists/*

FROM build_stage_proton AS trixie-proton-root
WORKDIR ${STEAMCMD_PATH}

FROM trixie-proton-root AS trixie-proton
USER ${USER}
