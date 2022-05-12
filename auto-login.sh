#!/bin/bash

#############
# VARIABLES #
#############

#this can be blank if that is the password, it will be verified
USERNAME="${1}"

#this can be blank if that is the password
PW="${2}"

#############
# FUNCTIONS #
#############

#given a string creates data for /etc/kcpassword
function kcpasswordEncode {

	#ascii string
	local thisString="${1}"
	local i
			
	#macOS cipher hex ascii representation array
	local cipherHex_array=( 7D 89 52 23 D2 BC DD EA A3 B9 1F )

	#converted to hex representation with spaces
	local thisStringHex_array=( $(echo -n "${thisString}" | xxd -p -u | sed 's/../& /g') )

	#get padding by subtraction if under 12 
	if [ "${#thisStringHex_array[@]}" -lt 12  ]; then
		local padding=$(( 12 -  ${#thisStringHex_array[@]} ))
	#get padding by subtracting remainder of modulo 12 if over 12 
	elif [ "$(( ${#thisStringHex_array[@]} % 12 ))" -ne 0  ]; then
		local padding=$(( (12 - ${#thisStringHex_array[@]} % 12) ))
	#otherwise even multiples of 12 still need 12 padding
	else
		local padding=12
	fi	

	#cycle through each element of the array + padding
	for ((i=0; i < $(( ${#thisStringHex_array[@]} + ${padding})); i++)); do
		#use modulus to loop through the cipher array elements
		local charHex_cipher=${cipherHex_array[$(( $i % 11 ))]}

		#get the current hex representation element
		local charHex=${thisStringHex_array[$i]}
	
		#use $(( shell Aritmethic )) to ^ XOR the two 0x## values (extra padding is 0x00) 
		#take decimal value and printf convert to two char hex value
		#use xxd to convert hex to actual value and append to the encodedString variable
		local encodedString+=$(printf "%02X" "$(( 0x${charHex_cipher} ^ 0x${charHex:-00} ))" | xxd -r -p)
	done

	#return the string without a newline
	echo -n "${encodedString}"
}

########
# MAIN #
########

#quit if not root
if [ "${UID}" != 0 ]; then
	echo "Please run as root, exiting."
	exit 1
fi

#if we have a USERNAME
if [ -n "${USERNAME}" ]; then 

	#check user
	if ! id "${USERNAME}" &> /dev/null; then
		echo "User '${USERNAME}' not found, exiting."
		exit 1
	fi

	if ! /usr/bin/dscl /Search -authonly "${USERNAME}" "${PW}" &> /dev/null; then
		echo "Invalid password for '${USERNAME}', exiting."
		exit 1
	fi

	#encode password and write file 
	kcpasswordEncode "${PW}" > /etc/kcpassword

	#ensure ownership and permissions (600)
	chown root:wheel /etc/kcpassword
	chmod u=rw,go= /etc/kcpassword

	#turn on auto login
	/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "${USERNAME}"

	echo "Auto login enabled for '${USERNAME}'"
#if not USERNAME turn OFF
else
	[ -f /etc/kcpassword ] && rm -f /etc/kcpassword
	/usr/bin/defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser &> /dev/null
	echo "Auto login disabled"
fi

exit 0
