#openssl x509 -in aps_development.cer -inform DER -out developer_identity.pem -outform PEM  
#openssl pkcs12 -nocerts -in push_dev.p12 -out push_dev.pem  
#openssl pkcs12 -export -inkey push_dev.pem -in developer_identity.pem -out iphone_dev.p12  
openssl pkcs12 -in push_dev.p12 -out push_dev.pem -nodes -clcerts
