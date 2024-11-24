#!/bin/bash
if [[ -d "/opt/steam/new-cstrike" ]]; then
    cp -R /opt/steam/new-cstrike/* /opt/steam/hlds/cstrike/
fi

exec /opt/steam/hlds/hlds_run $@