is_64bit() {
  [[ "${TRAVIS_SMALLTALK_VERSION}" == *"-64" ]]
}

is_32bit() {
  ! is_64bit
}

is_etoys() {
  [[ "${TRAVIS_SMALLTALK_VERSION}" == "Etoys"* ]]
}

is_Squeak_50() {
  [[ "${TRAVIS_SMALLTALK_VERSION}" == "Squeak-5.0" ]]
}

is_file() {
  [[ -f $1 ]]
}

is_dir() {
  [[ -d $1 ]]
}

is_nonzero() {
  [[ $1 -ne 0 ]]
}

travis_fold() {
  local action=$1
  local name=$2
  local title="${3:-}"

  if [[ "${TRAVIS:-}" = "true" ]]; then
    echo -en "travis_fold:${action}:${name}\r\033[0K"
  fi
  if [[ -n "${title}" ]]; then
    echo -e "\033[34;1m${title}\033[0m"
  fi
}
