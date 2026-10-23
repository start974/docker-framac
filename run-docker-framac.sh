#!/bin/sh
REPO=start974/
IMAGE=framac
TAG=33.0

if [ -z "$SUDO_UID" ]
then
  # not in sudo
  USER_ID=`id -u`
  USER_NAME=`id -n -u`
else
  # in a sudo script
  USER_ID=${SUDO_UID}
  USER_NAME=${SUDO_USER}
fi

# The GUIs are displayed in a web browser through noVNC:
# http://localhost:6080/vnc.html?autoconnect=1&resize=remote
docker run --rm --tty --interactive \
  --volume ${PWD}:/workspace:rw \
  --env USERNAME=${USER_NAME} --env USERID=${USER_ID} \
  --publish 127.0.0.1:6080:6080 \
  --shm-size 1g \
  --workdir /workspace \
  --name ${IMAGE} \
  ${REPO}${IMAGE}:${TAG}
