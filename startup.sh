#!/bin/sh
# Startup script for docker images to run in the container as
# the same user as on the host machine. Should be set as the ENTRYPOINT.
#
# The USERNAME and USERID should be set in the environment. Typical use is:
# docker run --rm --tty --interactive \
# 			 --env="USERNAME=`id -n -u`" --env="USERID=`id -u`" \
#	  		 --volume "$(PWD):/workspace:rw" \
# 			 --name container_name \
# 			 --publish 127.0.0.1:6080:6080 \
# 			 --workdir /workspace \
# 			 repo/image:tag

# Start a virtual X server with VNC and serve it through noVNC on port 6080
# (publish it with --publish 127.0.0.1:6080:6080), so that the GUIs can be
# used from a web browser. Set NOVNC=0 to use the X server of the host instead.
if [ "${NOVNC}" != "0" ]
then
  export DISPLAY=:1
  Xvnc :1 -geometry ${GEOMETRY:-1600x900} -depth 24 -SecurityTypes None \
       -localhost yes -AlwaysShared > /tmp/xvnc.log 2>&1 &
  websockify --web /usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
  echo "# GUIs (frama-c-gui, why3 ide) are displayed in your web browser at:"
  echo "#   http://localhost:6080/vnc.html?autoconnect=1&resize=remote"
fi

# Start the XFCE desktop in the VNC session as the given user
start_desktop() {
  if [ "${NOVNC}" != "0" ]
  then
    su $1 -c "cd /workspace 2>/dev/null; dbus-launch --exit-with-session startxfce4 > /tmp/xfce-$1.log 2>&1 &"
  fi
}

if [ -z "${USERNAME+x}" ]
then
  echo "# Warning: no USERNAME specified, running as root"
  echo "# Run docker with --env=\"USERNAME=<user name>\" --env=\"USERID=<user id>\""
  start_desktop root
  exec /bin/bash
fi
if [ -z "${USERID+x}" ]
then
  echo "#Warning: no USERID specified, running as root"
  echo "# Run docker with --env=\"USERNAME=<user name>\" --env=\"USERID=<user id>\""
  start_desktop root
  exec /bin/bash
fi
# Suppress spurious warnings about failure to connect to the accessibility bus
export NO_AT_BRIDGE=1
useradd --create-home --skel /root --shell /bin/bash --user-group --password ubuntu --non-unique --uid $USERID $USERNAME
start_desktop $USERNAME
exec su $USERNAME
