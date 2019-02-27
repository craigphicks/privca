#!/bin/bash
# 
# craigphicks 2019
set -u


Existing_CA_CN=""

function _get_CA_CN {
    shopt -s nullglob
    afn1=(./ca/private/*.key)
    afn2=(./ca/public/*.crt)
    if [[ ${#afn1[@]} -eq 0 ]] && [[ ${#afn2[@]} -eq 0 ]] ; then
        Existing_CA_CN=""	
	return 1
    fi
    
    if [[ ${#afn1[@]} -eq 1 ]] && [[ ${#afn2[@]} -eq 1 ]] ; then
	cn1=$(basename ${afn1[0]%.*})
	cn2=$(basename ${afn2[0]%.*})
	if [[ "$cn1" == "$cn2" ]] ; then
            Existing_CA_CN=$cn1
	    return 0
	fi
    fi
    echo "ERROR: illegal CA file combination found" >& 2
    exit 111
}

function CreateCA {

    ! _get_CA_CN  || { echo "CA Already exists: $Existing_CA_CN" >&2 ; exit 1; }

    CA_CN=${1}
    CA_ORG=${2}

    CAKeyFN=./ca/private/${CA_CN}.key
    CACrtFN=./ca/public/${CA_CN}.crt

    if [[ ! -d ./ca/private ]] ; then
	mkdir -p ./ca/private || exit 2
	sudo chmod 700 ./ca/private || exit 3
    fi
    if [[ ! -d ./ca/public ]] ; then
	mkdir -p ./ca/public || exit 4
    fi
    #
    # Create the Root Key
    #
    openssl genrsa -out ${CAKeyFN} 2048 || exit 5

    #
    # Now self-sign this certificate using the root key.
    #
    # CN: CommonName
    # OU: OrganizationalUnit
    # O: Organization
    # L: Locality
    # S: StateOrProvinceName
    # C: CountryName
    #
    openssl req -x509 \
            -new \
            -nodes \
            -key ${CAKeyFN} \
            -sha256 \
            -days 3650 \
            -subj "/C=US/ST=--/L=--/O=${CA_ORG}/OU=--/CN=${CA_CN}" \
            -out ${CACrtFN} || exit 6


    if [[ ! -d ./export/public ]] ; then mkdir -p ./export/public || exit 8 ; fi

    ln -s ${CACrtFN} ./export/public/ || exit 9;

    
}


function CreateLeaf {

    _get_CA_CN || { echo "Must create CA first"; exit 11; }
    CA_CN=${Existing_CA_CN}
    LEAF_CN=${1}
#    LEAF_CN_PRFX=${1}
#    LEAF_CN=${LEAF_CN_PRFX}--${CA_CN}
    subjectAltNameArg=${2}
    

    CAKeyFN=./ca/private/${CA_CN}.key
    CACrtFN=./ca/public/${CA_CN}.crt
    LEAFKeyFN=./private/${LEAF_CN}.key
    LEAFCsrFN=./temp/${LEAF_CN}.csr
    LEAFCrtFN=./public/${LEAF_CN}.crt

    [[ -d ./private ]] || { mkdir ./private || exit 12; }
    [[ -d ./public ]] || { mkdir ./public || exit 12; }
    chmod 750 ./private || exit 12; 
    [[ -d ./temp ]] || { mkdir ./temp || exit 12; }
	
    
    for f in ${LEAFKeyFN} ${LEAFCrtFN} ; do
	if [[ -f $f ]] ; then echo "$f already exists"; exit 15; fi
    done

    #
    # Create A Certificate
    #
    if ! openssl genrsa -out ${LEAFKeyFN} 2048
    then exit 16
    fi

    #
    # Now generate the certificate signing request.
    #
    if ! openssl req -new \
            -key ${LEAFKeyFN} \
            -subj "/C=US/ST=--/L=--/O=--/OU=--/CN=${LEAF_CN}" \
            -out ${LEAFCsrFN} 
    then exit 17
    fi

    #
    # Now generate the final certificate from the signing request.
    #
    if ! openssl x509 -req \
            -in ${LEAFCsrFN} \
            -CA ${CACrtFN} \
            -CAkey ${CAKeyFN} \
            -CAcreateserial \
	    -extfile <(printf "subjectAltName=${subjectAltNameArg}") \
            -out ${LEAFCrtFN} -days 3650 -sha256 
    then exit 18
    fi

    chmod -R 640 ${LEAFKeyFN} || exit 19
#    [[ ! -z ${SUDO_USER-""} ]] || { chown :$SUDO_USER ${LEAFKeyFN} || exit 19; }
    
}


function MakeForLighttpd {

    [[ $# -eq 1 ]] || { echo "one args only: server common name"; exit 31; }
    _get_CA_CN || { echo "Must create CA first"; exit 32; }

    CA_CN=${Existing_CA_CN}
    SRV_CN=${1}
#    SRV_CN_PRFX=${1}
#    SRV_CN=${SRV_CN_PRFX}--${CA_CN}

    CACrtFN=./ca/public/${CA_CN}.crt

    SrvKeyFN=./private/${SRV_CN}.key
    SrvCrtFN=./public/${SRV_CN}.crt

    mkdir -p ./export/private
    mkdir -p ./export/public
    chmod 750 ./private || exit 33
    
    ExpSrvKeyCrtFN=./export/private/${SRV_CN}.key-crt.pem
    
    cat ${SrvKeyFN} ${SrvCrtFN} > ${ExpSrvKeyCrtFN} || exit 35;
    chmod 640 ${ExpSrvKeyCrtFN} || exit 36;
#    [[ ! -z ${SUDO_USER-""} ]] || { chown :$SUDO_USER ${SrvKeyCrtFN} || exit 37; }
    
#    cat ${CACrtFN} > ${SrvCAChainFN} || exit 38;
    
}


function MakeForClientSideAuth_P12 {
    [[ $# -eq 1 ]] || { echo "one args only: client common name"; exit 41; }
    _get_CA_CN || { echo "Must create CA first"; exit 42; }
    CA_CN=${Existing_CA_CN}
    CL_CN=${1}
#    CL_CN_PRFX=${1}
#    CL_CN=${CL_CN_PRFX}--${CA_CN}
    ExpClientP12FN=./export/private/${CL_CN}.p12
    
    openssl pkcs12 -export -in ./public/${CL_CN}.crt \
	    -inkey ./private/${CL_CN}.key \
	    -certfile ./ca/public/${CA_CN}.crt \
	    -out ${ExpClientP12FN} || exit 44

    chmod 640 ${ExpClientP12FN} || exit 46;
#    [[ ! -z ${SUDO_USER-""} ]] || { chown :$SUDO_USER ${LEAFKeyFN} || exit 47; }
   
}

trap "on_exit" 0

function on_exit {
    exitval=$?
    if [[ $exitval -eq 0 ]] ;
    then echo "SUCCESS"
    else echo "FAILED with error $exitval"
    fi
    $(exit $exitval)
}


function Usage {
thisprog=$(basename $0)
cat <<EOF_
 NOTE: NO SPACES ALLOWED IN COMMON NAMES 
 $thisprog CreateCA <CA Common Name> <CA organization name>
 $thisprog CreateServer <Server common name> <subjectAltNames> 
 $thisprog CreateClient <Client common name> <subjectAltNames> 

 Examples:
 $thisprog CreateCA HomeLan "Self managed private certs"
 $thisprog CreateServer Server1 DNS:pihole.home.lan,DNS:pihole,IP:192.168.1.20
 $thisprog CreateClient Client1 ""
EOF_

}

if [[ $# -lt 2 ]] ; then Usage ; exit 1; fi
case $1 in 
    CreateCA)
	if [[ $# -eq 3 ]] ; then
	    CreateCA ${2} "${3}";
	else Usage;
	fi
	;;
    CreateServer)
	if [[ $# -eq 3 ]] ; then
	    CreateLeaf ${2} ${3} 
	    MakeForLighttpd ${2}
	else Usage;
	fi
	;;
    CreateClient)
	if [[ $# -eq 2 ]] ; then
	    CreateLeaf ${2} "email:${2}" 
	    MakeForClientSideAuth_P12 ${2}
	else Usage;
	fi
	;;
    *) Usage ; exit 1;
       ;;
esac

exit 0
