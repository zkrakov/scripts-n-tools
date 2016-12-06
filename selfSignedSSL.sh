#!/bin/bash
set -e
RED=$(echo -e "\033[0;31m")
GRN=$(echo -e "\033[0;32m")
YEL=$(echo -e "\033[0;33m")
BLU=$(echo -e "\033[0;34m")
BOLD=$(echo -e "\033[1;29m")
LTRED=$(echo -e "\033[1;31m")
LTGRN=$(echo -e "\033[1;32m")
LTYEL=$(echo -e "\033[1;33m")
LTBLU=$(echo -e "\033[1;34m")
NOCLR=$(echo -e "\033[0m")
export HN="$(hostname)"
step_1="false"
step_2="false"
step_3="false"
step_4="false"
step_5="false"
step_6="false"
step_7="false"
step_8="false"
###############################################################################
function apacheOps() {
	centertext "Enabling Apache SSL Module" "red"
	a2enmod ssl
	if [[ ! -e /etc/apache2/ssl ]]; then
		centertext "Creating SSL Directories" "red"
	    mkdir -p /etc/apache2/ssl
	else
	    centertext "Existing SSL Directory... Continuing..." "grn"
	fi
	cd /etc/apache2/ssl

	centertext "Directory Listing of /etc/apache2/ssl" "yel"
	ls -l /etc/apache2/ssl
	
	centertext "Directory Listing of /etc/ssl/private" "yel"
	ls -l /etc/ssl/private
}
###############################################################################
function initialKey() {
	centertext "Generating Initial Key" "red"
	openssl genrsa -des3 -out $1.key 2048
}
###############################################################################
function secureKeys() {
	centertext "Creating a secure and insecure key" "red"
	openssl rsa -in $1.key -out $1.key.insecure
	mv $1.key $1.key.secure
	mv $1.key.insecure $1.key	
}
###############################################################################
function csrOps() {
	centertext "Creating Certificate Signing Request (CSR)" "red"
	openssl req -new -key $1.key -out $1.csr
	centertext "Self-Signing Request (KEY)" "red"
	openssl x509 -req -days 365 -in $1.csr -signkey $1.key -out $1.crt	
}
###############################################################################
function placeFiles() {
	centertext "Copying keys to their destination directories" "red"
	sudo cp -v $1.crt /etc/ssl/certs
	sudo cp -v $1.key /etc/ssl/private	
}
###############################################################################
function createPems() {
	centertext "Creating PEM files" "red"
	openssl rsa -in $1.key -text > $1.pem
	openssl x509 -inform PEM -in $1.crt > $1.pem
}
###############################################################################
function makePems() {
	centertext "Completing Certificate Operations" "red"
	cat $1.key > $1.pem
	cat $1.crt >> $1.pem
	cp -v $1.pem /etc/ssl/private
}
###############################################################################
function directoryOps() {
	centertext "Setting appropriate permissions and privileges" "yel"
	chmod -v 0640 /etc/ssl/private/$1*
	chmod -v 0640 /etc/apache2/ssl/$1*
	
	centertext "Directory Listing of /etc/apache2/ssl" "yel"
	ls -l /etc/apache2/ssl
	
	centertext "Directory Listing of /etc/ssl/private" "yel"
	ls -l /etc/ssl/private
}
###############################################################################
function makeSSL() {
	apacheOps
	initialKey "$1"
	secureKeys "$1"
	csrOps "$1"
	placeFiles "$1"
	createPems "$1"
	makePems "$1"
	directoryOps "$1"
	saythanks
}
###############################################################################
function centertext() {
	divider
	  if [[ "$2" == "red" ]]; then echo -n "${LTRED}" 
	elif [[ "$2" == "yel" ]]; then echo -n "${LTYEL}"
	elif [[ "$2" == "grn" ]]; then echo -n "${LTGRN}"
	elif [[ "$2" == "blu" ]]; then echo -n "${LTBLU}"
	else 						   echo -n "${LTRED}"
	fi
	echo -n "$1" | sed -e :a -e 's/^.\{1,80\}$/ & /;ta'; echo "${NOCLR}"
	divider
}
###############################################################################
function saythanks() {
	centertext "CONGRATULATIONS!!! Got SSL? Yup! Sure do! " "grn"
	echo "- All of your SSL files are located in: ${LTGRN}/etc/apache/ssl${NOCLR}"
	echo "- A 'pem' file was also created with your CRT and KEY files and "
	echo "  it was added it to your ${LTGRN}/etc/ssl/private${NOCLR} directory"
	divider
	echo "Have Fun!"	
	echo ""; echo ""
}
###############################################################################
function denied() {
	divider; centertext "OK... Thanks for playing! Have a nice day!" "grn"; divider
}
###############################################################################
function confirm() {
	echo -n "Are you sure you want to proceed? [${BOLD}Y${NOCLR}/n]  "
	read response
	if [[ "$response" =~ ^[nN]|[nN][oO]$ ]]; then
		denied
	else 
		makeSSL "$1"
	fi	
}
###############################################################################
function outputheader() {
	divider; centertext "Self-Signed SSL Certificate Creator" "yel"; divider
}
###############################################################################
function divider() {
	echo -n "${LTRED}"; perl -E 'say "=" x 80'; echo -n "${NOCLR}"
}
###############################################################################
export -f makeSSL
export -f saythanks
export -f denied
export -f confirm
export -f outputheader
export -f divider
export -f apacheOps
export -f initialKey
export -f secureKeys
export -f csrOps
export -f placeFiles
export -f createPems
export -f makePems
export -f directoryOps
###############################################################################
outputheader
echo "This will help you create and install a self-signed SSL Certificate with a"
echo "${LTGRN}2048-bit key${NOCLR} using an RSA encryption algorithm. This will provide your server"
echo "with a strong encrytption protocol ${LTGRN}(TLS 1.2)${NOCLR}, a strong key exchange ${LTGRN}(ECDHE_RSA)${NOCLR},"
echo "and a strong cipher ${LTGRN}(AES_256_GCM)${NOCLR}, and will serve you for 365 days."
echo ""
echo "It will give your server that new car smell, with a machine gun, and "
echo "missles, and spikes to keep you, your visitors, and your server safe."
echo "Ultimately providing you with that extra sumthin' sumthin' for your"
echo "privacy, security, and perhaps most importantly, peace of mind! ;-)"
echo ""
echo "The following directories are where we'll do this work."
echo "- /etc/apache/ssl"
echo "- /etc/ssl/private"
echo ""
echo "The default file name for the certificate is 'server'(.crt, .csr, etc). "
echo "You have the option of choosing a more distinguishable name, such as a hostname,"
echo "and we found this system's host name to be:"
echo ""; echo "${LTRED}${HN}${NOCLR}"
echo ""; echo -n "Would you prefer to use this hostname for your SSL certs? [${BOLD}Y${NOCLR}/n]  "
read use_hostname
if [[ "$use_hostname" =~ ^[nN]|[nN][oO]$ ]]; then
	confirm "server"
else
	confirm "$(hostname)"
fi
###############################################################################

exit 0
