#!/bin/bash

# -----------------------------------------------------------------------------------------------------------------------------------------
#
#   ██████╗ ██╗████████╗██╗  ██╗██╗   ██╗██████╗     ██████╗ ██████╗ ███╗   ███╗    ██╗███╗   ███╗██╗     ██╗  ██╗ ██████╗ ███████╗███████╗
#  ██╔════╝ ██║╚══██╔══╝██║  ██║██║   ██║██╔══██╗   ██╔════╝██╔═══██╗████╗ ████║   ██╔╝████╗ ████║██║     ██║  ██║██╔═══██╗██╔════╝╚══███╔╝
#  ██║  ███╗██║   ██║   ███████║██║   ██║██████╔╝   ██║     ██║   ██║██╔████╔██║  ██╔╝ ██╔████╔██║██║     ███████║██║   ██║█████╗    ███╔╝ 
#  ██║   ██║██║   ██║   ██╔══██║██║   ██║██╔══██╗   ██║     ██║   ██║██║╚██╔╝██║ ██╔╝  ██║╚██╔╝██║██║     ██╔══██║██║   ██║██╔══╝   ███╔╝  
#  ╚██████╔╝██║   ██║   ██║  ██║╚██████╔╝██████╔╝██╗╚██████╗╚██████╔╝██║ ╚═╝ ██║██╔╝   ██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗███████╗
#   ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝    ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝
#                                                                                                                                          
#    Generates a private key and a self-signed certificate for the given domains and IP addresses,
#    and imports it as a trusted root certificate authority in the keychain.
#
# -----------------------------------------------------------------------------------------------------------------------------------------

#    MIT License
#    
#    Copyright (c) 2024 Maxime Lhoez
#    
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#    
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#    
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.

# Get domains and IP addresses to be included in the certificate
san_input=""
echo "Enter Subject Alternative Name (SAN) domains (each separated by a space):"
echo "Example: 'localhost *.localhost' or leave blank and hit Enter to skip"
read -a domains 

ITER=0
for i in ${domains[@]}; do
    if [[ $ITER -ne 0 ]]; then
        san_input="${san_input},"
    fi
    san_input="${san_input}DNS:${i}"
    ((ITER++))
done

echo -e "\n"
echo "Enter Subject Alternative Name (SAN) IP addresses (each separated by a space):"
echo "Example: '127.0.0.1' or leave blank and hit Enter to skip"
read -a ips
ITER=0
for i in ${ips[@]}; do
    if [[ "${#domains[@]}" -ne 0 ]]; then
        san_input="${san_input},"
    fi
    san_input="${san_input}IP:${i}"
    ((ITER++))
done

if [[ "${#domains[@]}" -eq 0 && "${#ips[@]}" -eq 0 ]]; then
        echo "Error: you must provide at least one domain or IP address."
    exit 0
fi

# Generate self-signed certificate and private key
openssl \
    req \
    -x509 \
    -newkey \
    rsa:4096 \
    -sha256 \
    -days 3650 \
    -nodes \
    -keyout self-signed.key \
    -out self-signed.crt \
    -subj "/CN=localhost" \
    -addext "keyUsage=digitalSignature,keyEncipherment,keyCertSign" \
    -addext "extendedKeyUsage=serverAuth,clientAuth" \
    -addext "subjectAltName=${san_input}" \
    -addext "authorityKeyIdentifier=keyid,issuer" \
    -addext "basicConstraints=CA:TRUE" \
    -quiet

exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    echo "/!\ FAILED TO GENERATE THE CERTIFICATE (Exit code: $exit_code) /!\ "
    exit 0
fi

# Output certificate for verification if needed
while true; do
    read -n 1 -p "Do you wish to output the certificate (y/n)? " yn
    case $yn in
        y|Y )
            echo -e "\n"
            echo "-------------------------------------------------------------------------------------"
            echo "|                          BEGIN OUTPUT OF: self-signed.crt                         |"
            echo "-------------------------------------------------------------------------------------"
            echo -e "\n"
            openssl x509 -in localhost.test.crt -text -noout;
            echo -e "\n"
            echo "-------------------------------------------------------------------------------------"
            echo "|                           END OUTPUT OF: self-signed.crt                          |"                        
            echo "-------------------------------------------------------------------------------------"
            echo -e "\n"
            break;;
        n|N ) break;;
        * ) echo -e "\nPlease answer yes (y) or no (n).";;
    esac
done

# Add the certificate as a trusted root certificate authority in the Keychain
echo -e "\nPlease enter your password to install and trust the root certificate authority in the Keychain."
echo "Note: you might be asked for it twice (ctrl+c to skip and install manually)."
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain localhost.test.crt

exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    echo -e "\nROOT CERTIFICATE AUTHORITY SUCCESSFULLY INSTALLED AND TRUSTED IN THE KEYCHAIN!"
else
    echo -e "\n/!\ FAILED TO INSTALL TRUSTED ROOT CERTIFICATE AUTHORITY IN THE KEYCHAIN (Exit code: $exit_code) /!\ \n"
    echo "Please follow these steps to install and trust the certificate manually (MacOS):" 
    
    echo "   1. Open Keychain Access"
    echo "   2. Select 'System' on the left panel"
    echo "   3. Select 'Certificates' in the categories tabs"
    echo "   4. Select 'File > Import Items...', browse 'self-signed.pem' and click 'Open'"
    echo "   5. Double click on the newly imported certificate in the certificates list"
    echo "   6. Expand the 'Trust' section"
    echo "   7. Change 'When using this certificate' to 'Always Trust'"
    echo "   8. Close the dialog, and you'll be prompted for your password"
    echo "   9. Close and reopen any tabs that are using your target domain, which should now be trusted"
fi

echo -e \
"\nTo use these files on your server, simply copy both self-signed.csr and self-signed.key to your webserver,
and use like so:\n"

echo \
"Nginx:
   server {
       [...]
       ssl_certificate /etc/ssl/self-signed.crt;
       ssl_certificate_key /etc/ssl/self-signed.key;
       [...]
   }"