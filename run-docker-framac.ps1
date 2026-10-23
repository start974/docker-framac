# Has to be authorized using:
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
$REPO="start974/"
$IMAGE="framac"
$TAG="33.0"
# The GUIs are displayed in a web browser through noVNC:
# http://localhost:6080/vnc.html?autoconnect=1&resize=remote
docker run --rm --tty --interactive --volume "${PWD}:/workspace:rw" --workdir /workspace --publish 127.0.0.1:6080:6080 --shm-size 1g --name "${IMAGE}" "${REPO}${IMAGE}:${TAG}"
