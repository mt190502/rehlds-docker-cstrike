FROM debian:bookworm-slim

####################### ARGUMENTS ########################
#~ Versions
ARG amxmodx_version=1.10
ARG metamod_version=1.3.0.149
ARG reapi_version=5.24.0.300
ARG regamedll_version=5.26.0.668
ARG rehlds_version=3.13.0.788
ARG reunion_version=0.2.0.13

#~ URLs
ARG steamcmd_url="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
ARG amxmod_base_url="https://www.amxmodx.org/amxxdrop/${amxmodx_version}/amxmodx-latest-base-linux.tar.gz"
ARG amxmod_cstrike_url="https://www.amxmodx.org/amxxdrop/${amxmodx_version}/amxmodx-latest-cstrike-linux.tar.gz"
ARG metamod_url="https://github.com/rehlds/Metamod-R/releases/download/${metamod_version}/metamod-bin-${metamod_version}.zip"
ARG reapi_url="https://github.com/rehlds/ReAPI/releases/download/${reapi_version}/reapi-bin-${reapi_version}.zip"
ARG regamedll_url="https://github.com/rehlds/ReGameDLL_CS/releases/download/${regamedll_version}/regamedll-bin-${regamedll_version}.zip"
ARG rehlds_url="https://github.com/rehlds/ReHLDS/releases/download/${rehlds_version}/rehlds-bin-${rehlds_version}.zip"
ARG reunion_url="https://github.com/rehlds/ReUnion/releases/download/${reunion_version}/reunion-${reunion_version}.zip"
##########################################################



############# LOCALES & DEPENDENCIES & ENVs ##############
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates curl:i386 lib32gcc-s1 libstdc++6:i386 unzip xz-utils zip && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.utf8
ENV LC_ALL en_US.UTF-8
ENV CPU_MHZ=2300
##########################################################



########## CREATE STEAM USER & INSTALL STEAMCMD ##########
#~ Create steam user
RUN groupadd -r steam && useradd -r -g steam -m -d /opt/steam steam

#~ Install steamcmd
USER steam
WORKDIR /opt/steam
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ./lib/hlds.install /opt/steam
RUN curl -sL "$steamcmd_url" | tar xzvf - \
    && mkdir -p "$HOME/.steam" hlds/cstrike/config \
    && ln -s "$PWD/linux32" "$HOME/.steam/sdk32" \
    && ./steamcmd.sh +runscript hlds.install 

#~ Touch files for warnings
RUN touch hlds/cstrike/listip.cfg
RUN touch hlds/cstrike/banned.cfg
RUN touch hlds/cstrike/config/server.cfg
##########################################################



################ INSTALL REHLDS & PLUGINS ################
#~ Install reverse-engineered HLDS
RUN curl -sL "$rehlds_url" -o "rehlds.zip" \
    && unzip "rehlds.zip" -d "rehlds" \
    && cp -R rehlds/bin/linux32/* hlds/ 

#~ Install Metamod-R
RUN curl -sL "$metamod_url" -o "metamod.zip" \
    && unzip "metamod.zip" -d "metamod" \
    && cp -R metamod/addons hlds/cstrike/ \
    && touch hlds/cstrike/addons/metamod/plugins.ini \
    && sed -i 's/dlls\/cs\.so/addons\/metamod\/metamod_i386\.so/g' hlds/cstrike/liblist.gam

#~ Install AMX mod X
RUN curl -sL "$amxmod_base_url" | tar -C hlds/cstrike/ -zxvf - \
    && curl -sL "$amxmod_cstrike_url" | tar -C hlds/cstrike/ -zxvf - \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> hlds/cstrike/addons/metamod/plugins.ini \
    && cat hlds/cstrike/mapcycle.txt >> hlds/cstrike/addons/amxmodx/configs/maps.ini 

#~ Install ReGameDLL
RUN curl -sL "$regamedll_url" -o "regamedll.zip" \
    && unzip "regamedll.zip" -d "regamedll" \
    && cp -R regamedll/bin/linux32/cstrike hlds/

#~ Install ReAPI
RUN curl -sL "$reapi_url" -o "reapi.zip" \
    && unzip "reapi.zip" -d "reapi" \
    && cp -R reapi/addons/* hlds/cstrike/addons/

#~ Install ReUnion
RUN curl -sL "$reunion_url" -o "reunion.zip" \
    && unzip "reunion.zip" -d "reunion" \
    && mkdir -p hlds/cstrike/addons/reunion \
    && cp -R reunion/bin/Linux/* hlds/cstrike/addons/reunion/ \
    && cp -R reunion/reunion.cfg hlds/cstrike/ \
    && cp -R reunion/amxx/* hlds/cstrike/addons/amxmodx/scripting/ \
    && echo 'linux addons/reunion/reunion_mm_i386.so' >> hlds/cstrike/addons/metamod/plugins.ini \
    && sed -i 's/AuthVersion = 3/AuthVersion = 2/g; s/SteamIdHashSalt =/SteamIdHashSalt = 32/g' hlds/cstrike/reunion.cfg

#~ Install Custom AMX Plugins
COPY ./lib/amxmodx hlds/cstrike/addons/amxmodx/
RUN echo 'damager_reapi.amxx                 ; show damage' >> hlds/cstrike/addons/amxmodx/configs/plugins.ini \
    && echo 'next21_kill_assist.amxx             ; kill assist mode' >> hlds/cstrike/addons/amxmodx/configs/plugins.ini

#~ Clean up
RUN rm -rf "rehlds.zip" "rehlds" "metamod.zip" "metamod" "regamedll.zip" "regamedll" "reunion.zip" "reunion" "hlds.install" "reapi.zip" "reapi" 
##########################################################



############# PERMISSIONS & WORKDIR & PORTS ##############
#~ Copy default folder
COPY ./cstrike /opt/steam/hlds/cstrike/

#~ Copy wrapper script
COPY ./lib/wrapper.sh /opt/steam/hlds

#~ Change workdir and permissions
WORKDIR /opt/steam/hlds
USER root
RUN chown -R steam:steam /opt/steam
RUN chmod +x hlds_run hlds_linux
USER steam
RUN echo 90 > steam_appid.txt                # 90: cstrike

#~ Expose ports
EXPOSE 27015 27015/udp

#~ Change default entrypoint
ENTRYPOINT ["./wrapper.sh"]
##########################################################