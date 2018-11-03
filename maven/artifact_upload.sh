#!/usr/bin/env bash

set -o errexit
set -o pipefail

VERBOSE=0
ISWIZARD=0
EXPDIR=""
RMUSER=""
RMPWD=""
RMHOST=""
RMPORT=""
RMFOLDER=""
REPOID=""

REQURL=""

usage () {
  cat << EOF
  Uploads the Maven artifact to maven repository managers using
  Maven's deploy plugin

  Jar files should have its corresponding pom with the same name
  and different extension (jar/pom)

  USAGE: artifact_upload.sh [-v] [-h] [-e] [-u] [-p] [-h] [-P] [-r]

    -w   Wizard
    -V   Shows the current maven version
    -h   Show script help manual
    -v   Make make verbose
    -e   Folder to look for Jars and POMs. Defaults to current folder's 'export' folder
    -u   Repo manager username. Defaults to admin
    -p   Repo manager user password. Defaults to admin123
    -H   Repo manager hostname
    -P   Port of the repo manager. Defaults to 8081
    -g   Repo manager's folders. Defaults to /repository/maven-releases/
    -r   Repository ID. Defaults to nexus

  NOTE: Repo manager currently support is nexus
EOF
}

chkTools () {
  if ! command -v mvn >/dev/null; then
    >&2 echo "Maven is not installed in your system."
    exit 127
  fi
}

absPath () {
  if [[ -d "$1" ]]
  then
      pushd "$1" >/dev/null
      pwd
      popd >/dev/null
  elif [[ -e $1 ]]
  then
      pushd "$(dirname "$1")" >/dev/null
      echo "$(pwd)/$(basename "$1")"
      popd >/dev/null
  else
      >&2 echo "${1} does not exist!"
      exit 127
  fi
}

log () {
  if (( VERBOSE )); then
    echo $1
  fi
}

getVer () {
  echo "MAVEN: $(mvn --version | head -1)" 
}

procJars () {
  local pf=""
  local tot=0
  local mvnCmd=""

  for jf in $(find ${EXPDIR} -name '*.jar'); do
    pf=$(sed s/\.jar\$/\.pom/ <<< "${jf}")
    if [[ ! -f "${pf}"  ]]; then
       >&2 echo "Equivalent POM file doesn't exists for ${jf}"
      continue
    fi
    mvnCmd="mvn deploy:deploy-file -DpomFile=${pf} -Dfile=${jf} -Durl=${REQURL} -DrepositoryId=${REPOID}"
    log "${mvnCmd}"       
    set +e
    eval "${mvnCmd}"
    set -e
    (( ++tot ))
  done
  echo "TOTAL FILES UPLOADED: ${tot}"
}

runWizard () {
  if [[ -z "${EXPDIR}" ]]; then
    read -r -p "Where is/are the jar/s and pom/s located [defaul: ./export]: " EXPDIR
  fi

  if [[ -z "${RMUSER}" ]]; then
    read -r -p "Repo usename (default: admin): " RMUSER
  fi

  if [[ -z "${RMPWD}" ]]; then
    read -r -p "Repo user password (default: admin123); " RMPWD
  fi

  if [[ -z "${RMHOST}" ]]; then
    read -r -p "Repo hostname (default: localhost): " RMHOST
  fi

  if [[ -z "${RMPORT}" ]]; then
    read -r -p "Repo port (default: 8081): " RMPORT
  fi

  if [[ -z "${RMFOLDER}" ]]; then
    read -r -p "Repo folder (default: /repository/maven-release/): " RMFOLDER
  fi

  if [[ -z "${REPOID}" ]]; then
    read -r -p "Repo ID (default: nexus): " REPOID
  fi
}

prepArgs () {
  EXPDIR=${EXPDIR:-"export"}
  log "Using export directory: ${EXPDIR}"

  RMUSER=${RMUSER:-"admin"}
  log "Using username: ${RMUSER}"

  RMPWD=${RMPWD:-"admin123"}
  log "Using password: ${RMPWD}"

  RMHOST=${RMHOST:-"localhost"}
  log "Using hostname: ${RMHOST}"

  RMPORT=${RMPORT:-"8081"}
  log "Using port: ${RMPORT}"

  RMFOLDER=${RMFOLDER:-"/repository/maven-releases/"}
  log "Using repo folder: ${RMFOLDER}"

  REPOID=${REPOID:-"nexus"}
  log "Using repo ID: ${REPOID}"

  if [[ ! "${EXPDIR:0:1}" = "/" ]]; then
    EXPDIR=$(absPath "${EXPDIR}")
  fi


  if [[ ! -d "${EXPDIR}" ]]; then
    >&2 echo "${EXPDIR} doesn't exists." 
    exit 127
  fi 

  log "Resolved export path: ${EXPDIR}"

  REQURL="http://${RMUSER}:${RMPWD}@${RMHOST}:${RMPORT}${RMFOLDER}"
  log "Generated URL: ${REQURL}"   

}


init () {
  chkTools

  if [[ $# = 0 ]]; then
    usage
    exit
  fi

  while getopts "vhwe:u:p:H:P:g:r:" optn; do
    case "${optn}" in
      "h")
        usage
        ;;
      "w")
        ISWIZARD=1
        ;;
      "v")
        VERBOSE=1
        ;;
      "e")
        EXPDIR="${OPTARG}"
        ;;
      "u")
        RMUSER="${OPTARG}"
        ;;
      "p")
        RMPWD="${OPTARG}"
        ;;
      "H")
        RMHOST="${OPTARG}"
        ;;
      "P")
        RMPORT="${OPTARG}"
        ;;
      "g")
        RMFOLDER="${OPTARG}"
        ;;
      "r")
        REPOID="${OPTARG}"
        ;;
      "?")
        usage
        exit 1
        ;;
      *)
        usage
        >&2 echo "ERROR: An unknown error occured. Check your switches."
        exit 1
        ;;
    esac 
  done

  if (( ISWIZARD )); then
    runWizard
  fi
  prepArgs
  procJars
  exit 0
}

init "$@"
