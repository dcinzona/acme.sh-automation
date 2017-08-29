#!/bin/bash

# Load TickTick for JSON processing
# https://github.com/kristopolous/TickTick
. vendor/ticktick.sh


# Get your Cloudflare API key from https://www.cloudflare.com/a/profile
export CF_Key="$CF_API_KEY"
export CF_Email="$CF_API_EMAIL"

DIR=`pwd`
PASSWD=$(openssl rand -base64 32)
RUN='--staging --force'
FORCE=''

_startswith() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep "^$_sub" >/dev/null 2>&1
}

_contains() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "$_sub" >/dev/null 2>&1
}

_issue(){
    echo "$1"
    # return
    ~/.acme.sh/acme.sh --issue \
        --dns dns_cf --dnssleep 25 \
        $1 \
        --cert-file      "$CERTPATH/$PRIMARY_DOMAIN.cer" \
        --key-file       "$CERTPATH/$PRIMARY_DOMAIN.key" \
        --ca-file        "$CERTPATH/$PRIMARY_DOMAIN.ca.cer" \
        --fullchain-file "$FULLCHAIN" \
        $RUN $FORCE
    _genPKCS12
}

_genPKCS12(){
    echo "PFX PASSWORD: $PASSWD"
    openssl pkcs12 -export \
        -in $FULLCHAIN \
        -inkey $KEY \
        -name "certbot_autogen" \
        -out "$CERTPATH/$PRIMARY_DOMAIN.pfx" \
        -password "pass:$PASSWD"
    _genJKS
}

_genJKS(){
    echo "JKS PASSWORD: $PASSWD"
    keytool -noprompt \
            -importkeystore \
            -deststorepass $PASSWD \
            -destkeystore "$CERTPATH/$PRIMARY_DOMAIN.jks" \
            -srckeystore "$CERTPATH/$PRIMARY_DOMAIN.pfx" \
            -srcstorepass $PASSWD \
            -srcstoretype PKCS12 > /dev/null 2>&1
}

_process(){
  NO_VALUE="no"
  _primaryDomain='';
  _otherDomainsCsv='';
  _altdomains="$NO_VALUE"
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      --help | -h)
        showhelp
        return
        ;;
      --cfkey)
        CF_Key="$2"
        shift
        ;;
      --run | -r)
        RUN=""
        shift
        ;;
      --force | -f)
        FORCE="--force"
        shift
        ;;
      --cfemail)
        CF_Email="$2"
        shift
        ;;
      --primary-domain | -p)
        _primaryDomain="$2"
        if _contains "$_altdomains" "$2"; then
          _altdomains=$(echo "$_altdomains" | tr " -d $2" '')
        fi
        shift
        ;;
      --alternates | -d)
        _dvalue="-d $2"
        if _contains "$2" ','; then
          for f in $(echo "$2" | tr ',' ' '); do
            [ -z "$f" ] && continue
            [ "$_primaryDomain" = "$f" ] && continue
            _dvalue="-d $f"

            if [ "$_altdomains" = "$NO_VALUE" ]; then
              _altdomains="$_dvalue"
            else
              _altdomains="$_altdomains $_dvalue"
            fi
          done
        else
          if [ "$_altdomains" = "$NO_VALUE" ]; then
            _altdomains="$_dvalue"
          else
            _altdomains="$_altdomains $_dvalue"
          fi
        fi
        shift
        ;;
    esac

    shift 1
  done
  _errors=''
  if [ -z "$_primaryDomain" ]; then
    _err    "Primary domain is required."
    #_normal "Example: gencerts.sh --primary-domain site1.mydomain.com"
    _errors=1
  fi
  if [ -z "$CF_Key" ]; then
    _err    "Cloudflare API Key is required."
    #_normal "Example: gencerts.sh --cfkey my-cloudflare-api-key"
    _errors=1
  fi
  if [ -z "$CF_Email" ]; then
    _err    "Cloudflare Email is required."
    #_normal "Example: gencerts.sh --cfemail my-cf-email@example.com"
    _errors=1
  fi
  [ -n "$_errors" ] && showhelp && return

  
  _flags="-d $_primaryDomain"

  if [ ! "$_altdomains" = "$NO_VALUE" ]; then
    _flags="$_flags $_altdomains"
  fi

  _setpaths "$_primaryDomain"
  _issue "$_flags" #&& _genPKCS12 && _genJKS
}

_setpaths(){
  PRIMARY_DOMAIN="$1"
  _deployment="$DIR/deploy"
  CERTPATH="$_deployment/$PRIMARY_DOMAIN"
  if [ ! -d $_deployment ];then
      mkdir -m 0700 $_deployment
  fi
  if [ ! -d $CERTPATH ];then
      mkdir -m 0700 $CERTPATH
  fi
  CERT="$CERTPATH/$PRIMARY_DOMAIN.cer"
  KEY="$CERTPATH/$PRIMARY_DOMAIN.key"
  FULLCHAIN="$CERTPATH/fullchain.cer"
}

main() {
  [ -z "$1" ] && showhelp && return
  if _startswith "$1" '-'; then _process "$@"; else showhelp; fi
}

showhelp() {
  example=`cat jsonexample.json`
  echo "
Usage: gencert.sh  command ...[parameters]....

Commands:
  --help, -h              Show this help message.
  --cfkey                 Set your Cloudflare API key *REQUIRED
  --cfemail               Set your Cloudflare API email *REQUIRED
  --primary-domain        The primary domain used to generate certs *REQUIRED
  --alternates            Comma separated list of domains to grab in addition to the primary-domain
  --json, -j              File path containing JSON file with config settings 
  --run, -r               Disables --staging and --force flags and runs on production
  --force, -f             Sets the --force flag.  Use with --run to force renewal
  
JSON Example:
  $example
  "
}

_normal() {
    printf '\e[0m'
    printf -- "%b" "$1"
    printf "\n" >&2
}

_err() {
  printf "\n" >&2
  printf '\e[0;31m'
  if [ -z "$2" ]; then
    printf -- "%b" "$1"
  else
    printf "$1='$2'" >&2
  fi
  printf '\e[0m'
  printf "\n" >&2
  return 1
}


main "$@"

