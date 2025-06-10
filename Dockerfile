FROM debian:bookworm-slim AS build_stage

ARG DEBIAN_FRONTEND="noninteractive"
ARG PUID=1000
ENV USER=steam
ENV HOMEDIR="/home/${USER}"
ENV STEAMCMDDIR="${HOMEDIR}/steamcmd"

ADD --chmod=644 https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz /tmp/steamcmd_linux.tar.gz

RUN set -x \
	# Install, update & upgrade packages
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
	    ca-certificates=20230311 \
	    lib32gcc-s1=12.2.0-14+deb12u1 \
		lib32stdc++6=12.2.0-14+deb12u1 \
		locales=2.36-9+deb12u10 \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	# Create unprivileged user
	&& useradd -u "${PUID}" -m "${USER}" \
	# Download SteamCMD, execute as user
	&& su "${USER}" -c \
		"mkdir -p \"${STEAMCMDDIR}\" \
                && tar xvzf /tmp/steamcmd_linux.tar.gz -C \"${STEAMCMDDIR}\" \
                && \"./${STEAMCMDDIR}/steamcmd.sh\" +quit \
                && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${STEAMCMDDIR}/steamservice.so\" \
                && mkdir -p \"${HOMEDIR}/.steam/sdk32\" \
                && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${HOMEDIR}/.steam/sdk32/steamclient.so\" \
                && ln -s \"${STEAMCMDDIR}/linux32/steamcmd\" \"${STEAMCMDDIR}/linux32/steam\" \
                && mkdir -p \"${HOMEDIR}/.steam/sdk64\" \
                && ln -s \"${STEAMCMDDIR}/linux64/steamclient.so\" \"${HOMEDIR}/.steam/sdk64/steamclient.so\" \
                && ln -s \"${STEAMCMDDIR}/linux64/steamcmd\" \"${STEAMCMDDIR}/linux64/steam\" \
                && ln -s \"${STEAMCMDDIR}/steamcmd.sh\" \"${STEAMCMDDIR}/steam.sh\"" \
	# Symlink steamclient.so; So misconfigured dedicated servers can find it
 	&& ln -s "${STEAMCMDDIR}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so" \
 	&& rm -f /tmp/steamcmd_linux.tar.gz \
	&& rm -rf /var/lib/apt/lists/*

FROM build_stage AS bookworm-root
WORKDIR ${STEAMCMDDIR}

FROM bookworm-root AS bookworm
# Switch to user
USER ${USER}

FROM bookworm-root AS build_stage_wine

ARG DEBIAN_FRONTEND="noninteractive"
ARG WINE_BRANCH=devel
ARG WINE_VERSION=9.12~bookworm-1
ARG WINE_MONO_VERSION=9.2.0

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
WORKDIR ${STEAMCMDDIR}

FROM bookworm-wine-root AS bookworm-wine
# Switch to user
USER ${USER}
