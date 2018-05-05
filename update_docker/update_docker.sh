#!/bin/bash
#==========================================================
#          FILE: update_docker.sh
#   DESCRIPTION: update docker'version for swarm worker node
#       CREATED: 2017/07/20
#        AUTHOR: honglei
#=========================================================

set -e

BASEPATH=`cd $(dirname "$0"); pwd`

. ${BASEPATH}/common.sh
. ${BASEPATH}/constant.sh

MANAGER_NODE_IP=""
DOCKERD_LISTEN_ON="6732"

#---  FUNCTION  -------------------------------------------
#         NAME:  usage
#  DESCRIPTION:  Display usage information.
#----------------------------------------------------------
usage() {
    cat << EOT

  Usage :  update_docker.sh -M <manager node IP> [-P <dockerd listening on>]

  Examples:
    - update_docker.sh -M 10.10.10.1

  Options:
  -h  Display this message
  -M  Manager node IP address. 
  -P  The port which dockerd listenging on. The default value is 6732 
EOT
}   # ----------  end of function usage  ----------

echoinfo "update_docker.sh START." 
while getopts ":hM:P:" opt
do
  case "${opt}" in

    h )  usage; exit ${RETURN_CODE_NOMAL}     ;;
    M )  MANAGER_NODE_IP=$OPTARG              ;;
    P )  DOCKERD_LISTEN_ON=$OPTARG            ;;
    \?)  echo
         echolog "Option does not exist : $OPTARG"
         usage
         exit ${RETURN_CODE_ERROR_OPTION_NOT_EXIST}
         ;;

  esac    # --- end of case ---
done

# parameter check.
[ "X${MANAGER_NODE_IP}" == "X" ] && { echoerror "required parameter(MANAGER_NODE_IP) is missing."; exit ${RETURN_CODE_ERROR_REQUIRED_PARAMETER}; }

API_URL_PREFIX="http://${MANAGER_NODE_IP}:${DOCKERD_LISTEN_ON}/${API_VER}"
HOSTNAME=$(hostname -s)
chmod 755 ${BASEPATH}/jq

# STEP 1: update node availability.
echoinfo "STEP 1: update node availability."
function update_node_availability()
{
  _type=$1
  NODE_VERSION=$(curl -sk -X GET ${API_URL_PREFIX}/nodes/${HOSTNAME} | ${BASEPATH}/jq .Version.Index)
  [ "X${NODE_VERSION}" == "X" -o "X${NODE_VERSION}" == "Xnull" ] && { echoerror "update node ${HOSTNAME} failed. "; exit ${RETURN_CODE_ERROR_UPDATE_NODE}; }
  curl -s -X POST "${API_URL_PREFIX}/nodes/${HOSTNAME}/update?version=${NODE_VERSION}" -d "{\"Role\": \"worker\", \"Availability\": \"${_type}\"}"
  NODE_AVAILABILITY=$(curl -sk -X GET ${API_URL_PREFIX}/nodes/${HOSTNAME} | ${BASEPATH}/jq .Spec.Availability | sed 's/"//g')
  [ "X${NODE_AVAILABILITY}" == "X${_type}" ] || { echoerror "update node ${HOSTNAME} failed. "; exit ${RETURN_CODE_ERROR_UPDATE_NODE}; }
  return 0
}
update_node_availability "drain"

# SETP2: stop dockerd.
echoinfo "STEP 2: stop dockerd."
sleep 3
CONTAINER_NUM=$(docker ps -q | wc -l)
[ "${CONTAINER_NUM}" -ne 0 ] && { echoerror "container migration failed. "; exit ${RETURN_CODE_ERROR_CONTAINER_MIGRATION}; }
systemctl stop docker
[ "$?" -ne 0 ] && { echoerror "stop dockerd failed. "; exit ${RETURN_CODE_ERROR_STOP_DOCKERD}; }

TIMESTAMP=$(date +%Y%m%d%H%M%S)
DAEMON_JSON_PATH="/etc/docker/daemon.json"
DOCKER_SERVICE_PATH="/usr/lib/systemd/system/docker.service"
VAR_LIB_DOCKER_PATH="/var/lib/docker"
function backup()
{
  \cp "${DAEMON_JSON_PATH}" "${DAEMON_JSON_PATH}${TIMESTAMP}"
  \cp "${DOCKER_SERVICE_PATH}" "${DOCKER_SERVICE_PATH}${TIMESTAMP}"
  \cp -rf "${VAR_LIB_DOCKER_PATH}" "${VAR_LIB_DOCKER_PATH}${TIMESTAMP}"
  return 0
}
function backout()
{
  \cp "${DAEMON_JSON_PATH}${TIMESTAMP}" "${DAEMON_JSON_PATH}"
  \cp "${DOCKER_SERVICE_PATH}${TIMESTAMP}" "${DOCKER_SERVICE_PATH}"
  \cp -rf "${VAR_LIB_DOCKER_PATH}${TIMESTAMP}" "${VAR_LIB_DOCKER_PATH}"
  return 0
}
backup

# SETP3: update docker-engine.
echoinfo "SETP 3: update docker-engine."
yum clean all >/dev/null 2>&1
yum update -y -e 0 -d 0 docker-engine
backout

systemctl daemon-reload
systemctl start docker

update_node_availability "active"

echoinfo "update_docker.sh END." 

