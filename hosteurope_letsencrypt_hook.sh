#!/usr/bin/env bash

# This script requires the following credentials to hosteurope as environment variable
# export HE_DOMAIN="my.domain.org"
# export HE_CNUMBER="12345"
# export HE_PASSWORD="mypassword"
# where my.domain.org is the domain you signed for with hosteurope.

# Caution: Hosteurope has a default TTL for 1 day for entries. This script can only
# verify if the challenges are set on the hosteurope DNS servers.
# Challenge might fail if letsencrypt has already a cached entry.
# So use DNS-01 challenge with a hosteurope DNS server at a maximum rate of once per day.

function waitns {
    local ns="$1"
    local DNS_SYNC_TIMEOUT=300
    logger "Waiting up to $DNS_SYNC_TIMEOUT second for challenge "_acme-challenge.${DOMAIN}." to appear with ${TOKEN_VALUE} on ${ns}"
    for ctr in $(seq 1 "$DNS_SYNC_TIMEOUT"); do
        if [ "$(dig +short "@${ns}" TXT "_acme-challenge.${DOMAIN}." | grep "${TOKEN_VALUE}" | wc -l)" == "1" ]; then
            logger "Found challenge on ${ns} after ${ctr} trys."
            return 0
        fi
        sleep 1
    done
    logger "Can't find challenge on ${ns}"
    return 1

}

function deploy_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called once for every domain that needs to be
    # validated, including any alternative names you may have listed.
    #
    # Parameters:
    # - DOMAIN
    #   The domain name (CN or subject alternative name) being
    #   validated.
    # - TOKEN_FILENAME
    #   The name of the file containing the token to be served for HTTP
    #   validation. Should be served by your web server as
    #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
    # - TOKEN_VALUE
    #   The token value that needs to be served for validation. For DNS
    #   validation, this is what you want to put in the _acme-challenge
    #   TXT record. For HTTP validation it is the value that is expected
    #   be found in the $TOKEN_FILENAME file.
    
    logger "Deploy challenge DOMAIN=${DOMAIN}, TOKEN_FILENAME=${TOKEN_FILENAME}, TOKEN_VALUE=${TOKEN_VALUE}"
	
    # Hint: ${DOMAIN} is like owncloud.my.domain.org
    # for hosteurope you have to split it up in name=owncloud and domain=my.domain.org

    HE_NAME=$(echo ${DOMAIN} | sed "s/.$HE_DOMAIN//")
    hosteurope_domservice.sh ${HE_DOMAIN} add TXT "_acme-challenge.${HE_NAME}" "${TOKEN_VALUE}"
	
    # give name server time to sync the changes from the API calls
    sleep 10

    # Wait for all name servers to update each other
    for ns in $(dig +short NS "${HE_DOMAIN}."); do
        waitns "$ns"
        if [ $? -ne 0 ]; then
            clean_challenge ${DOMAIN} ${TOKEN_FILENAME} ${TOKEN_VALUE}
	    return 1
	fi
    done

    # Another pause is needed here (no idea why). Otherwise challenge fails quite often (>50%)
    sleep 30
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.
    logger "Clean challenge DOMAIN=${DOMAIN}, TOKEN_FILENAME=${TOKEN_FILENAME}, TOKEN_VALUE=${TOKEN_VALUE}"

    # Hint: ${DOMAIN} is like owncloud.my.domain.org
    # for hosteurope you have to split it up in name=owncloud and domain=my.domain.org
    HE_NAME=$(echo ${DOMAIN} | sed "s/.$HE_DOMAIN//")
	
    hosteurope_domservice.sh ${HE_DOMAIN} delete TXT "_acme-challenge.${HE_NAME}" "${TOKEN_VALUE}"
	
    # give the caches time to settle
    sleep 10
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - TIMESTAMP
    #   Timestamp when the specified certificate was created.
	
    logger "Deploy challenge DOMAIN=${DOMAIN}, KEYFILE=${KEYFILE}, CERTFILE=${CERTFILE}, FULLCHAINFILE=${FULLCHAINFILE}, CHAINFILE=${CHAINFILE}, TIMESTAMP=${TIMESTAMP}"

    systemctl reload apache
}

function unchanged_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    
    logger "Unchanged Cert DOMAIN=${DOMAIN}"
}

HANDLER=$1; shift; $HANDLER $@

