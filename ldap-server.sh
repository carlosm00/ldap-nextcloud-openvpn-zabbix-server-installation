#!/bin/bash
# 
#   Author/Autor: Carlos Mena.
#   https://github.com/carlosm00
#
#############################################################
#
# [EN] OPENLDAP INSTALLATION SCRIPT IN GNU/LINUX OS --> MUST BE EXUCUTED AS ROOT
#   1. OS and release discovery
#   2. Packages installation
#   3. Configuration
#   4. Zabbix agent
#
# [ES] SCRIPT DE INSTALACIÓN DE SERVICIO OPENLDAP EN SISTEMA OPERATIVO GNU/LINUX --> TIENE QUE SER EJECUTADO COMO ROOT
#   1. Descubrimiento de OS y versión
#   2. Instalación de paquetes
#   3. Configuración
#   4. Agente de Zabbix
#
# logs
mkdir /tmp/ldap_installation
PROGNAME=$(basename $0)
echo "${PROGNAME}:" >success_ldap.log
echo "${PROGNAME}:" >error_ldap.log
#
#############################################################
#
# [EN] Function for 3 - configuration / [ES] Función para 3 - configuración
#
conf () {
echo -n "[EN] Write your domain / [Es] Escriba su dominio : "
read DOM
echo $DOM | grep "." >>/tmp/ldap_installation/success_ldap.log
if [ $? != 0 ]
then
    echo "[EN] Your domain name must contain at least a dot / [ES] Su dominio debe contener mínimo un punto "
    echo "Example/Ejemplo: example.com "
    echo -n "[EN] Write your domain / [Es] Escriba su dominio : "
    read DOM
fi
echo -n "[EN] Write the INTERFACE your ldap service will be accessed trought / [Es] Escriba la INTERFAZ a la que se accederá a su servicio ldap : "
read INT
IP=`/sbin/ifconfig $INT | grep 'inet ' | cut -d "n" -f2 | cut -c4-`
if [ $? != 0 ]
then
    echo "[EN] That interface ($INT) does not exist / [ES] Esa interfaz ($INT) no existe"
    echo "Example/Ejemplo: eth0"
    echo -n "[EN] Write the INTERFACE your ldap service will be accessed trought / [Es] Escriba la INTERFAZ a la que se accederá a su servicio ldap :"
    read INT
    IP=`/sbin/ifconfig $INT | grep 'inet ' | cut -d "n" -f2 | cut -c4-`
fi

cd /etc/ldap/ 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
cp /etc/ldap/ldap.conf /etc/ldap/ldap-.conf 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
dc1=${DOM%.*}
dc2=`echo $DOM | cut -d "." -f 2`
cat << EOL > /etc/ldap/ldap.conf
BASE dc=$dc1,dc=$dc2
URI ldap://$IP
TLS_CACERT	/etc/ssl/certs/ca-certificates.crt
EOL
}
#
############################################################# 
#
# [EN] Function for 4 - zabbix agent / [ES] Función para 4 - agente de zabbix
#
zabbix_ip () {
    echo -n "[EN] Zabbix Server IP / [ES] IP del Servidor de Zabbix : "
    read $ZS
}
#
zbx_agn () {
echo -e -n "[EN] Do you want to enable this server as a ZABBIX AGENT? / [ES] ¿Desea habilitar este servidor como AGENTE de ZABBIX? \n[Y/n]: "
read
if [[ $REPLY == "y" ]] || [[ $REPLY == "Y" ]]
then
    apt -qq install zabbix-agent fping -y 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    cd /etc/zabbix 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    cp zabbix_agentd.conf zabbix_agentd--.conf 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
#
    zabbix_ip
    fping $ZS 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    if [ $? != 0 ]
    then
        echo -ne "[EN] This server is not reachable / [ES] Este servidor no es accesible \n [EN] Do you still want to use this IP ?/ [ES] ¿Sigue queriendo usar esta IP? \n [Y/n]: "
        read
        if [[ $REPLY != "y" ]] || [[ $REPLY != "Y" ]]
        then
            zabbix_ip
        fi
    fi
    cat << EOL > zabbix_agentd.conf
# [EN] ZABBIX AGENT CONFIG FILE [ES] Archivo de configuración de ZABBIX AGENT
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix-agent/zabbix_agentd.log
LogFileSize=0
DebugLevel=3
EnableRemoteCommands=1
LogRemoteCommands=1
Server=$ZS
ListenPort=10050
ServerActive=$ZS
Include=/etc/zabbix/zabbix_agentd.conf.d/*.conf
EOL
# [EN] This are the configuration steps for https://github.com/MrCirca/OpenLDAP-Cluster-Zabbix template / [ES] Estos son los pasos de configuración para la plantilla de https://github.com/MrCirca/OpenLDAP-Cluster-Zabbix
    mkdir /etc/zabbix/external_scripts 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    cd /etc/zabbix/external_scripts 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    wget -q https://raw.githubusercontent.com/MrCirca/OpenLDAP-Cluster-Zabbix/master/ldap_check_status.sh 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    chmod +x ldap_check_status.sh 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    cd /etc/zabbix/zabbix_agentd.conf.d 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    wget -q https://raw.githubusercontent.com/MrCirca/OpenLDAP-Cluster-Zabbix/master/openldap_cluster_status.conf 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
    service zabbix-agent restart 1>>/tmp/ldap_installation/success_ldap.log 2>>/tmp/ldap_installation/error_ldap.log
fi
}
#
############################################################# EXECUTION / EJECUCIÓN ##################################
#
# 1.
#
clear
OS=`grep ID_LIKE /etc/os-release | cut -c9-`
OSV=`grep VERSION_CODENAME /etc/os-release`
#
#
# 2. apt / dnf
if [[ $OS == *"buntu"* ]] || [[ $OS == *"ebian"* ]]
then
    apt -qq update 1>>success_ldap.log 2>>error_ldap.log
    apt -qq install -y slapd ldap-utils 2>>error_ldap.log
    dpkg-reconfigure slapd 2>>error_ldap.log
# [EN] Execution function for 3 / [ES] Ejecución de función para 3
    conf
# [EN] Execution function for 4 / [ES] Ejecución de función para 4
    zbx_agn 
# [EN] End / [ES] Fin
    echo "[EN] Installation finished! / [ES] ¡Instalación acabada!"
elif [[ $OS == *"edora"* ]]
then
    echo "[EN] This script is ONLY for Debian based OS / [ES] Este script es SOLO para sistemas operativos basados en Debian "
fi
