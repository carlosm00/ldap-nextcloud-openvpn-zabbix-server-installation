#!/bin/bash
# 
#   Author/Autor: Carlos M.
#   https://github.com/carlosm00
#
#############################################################
#
# [EN] THIS SCRIPT INSTALLS OPENVPN AS SERVICE (ACCORDING TO THEIR TUTORIAL ON https://openvpn.net/vpn-software-packages/) + (OPTIONAL) ZABBIX AGENT. ONLY FOR DEBIAN BASED OS. MUST BE EXECUTED AS ROOT.
#   1. OS and release discovery
#   2. Installation
#   3. (Optional) Zabbix agent
#
# [ES] ESTE SCRIPT INSTALA OPENVPN AS SERVICE (SEGÚN SU TUTORIAL EN https://openvpn.net/vpn-software-packages/) + (OPCIONAL) ZABBIX AGENT. SÓLO PARA SO BASADO EN DEBIAN. DEBE SER EJECUTADO COMO ROOT.
#   1. Descubrimiento de OS y versión
#   2. Instalación
#   3. (Opcional) Agente de Zabbix
#
#
# logs
PROGNAME=$(basename $0)
echo "${PROGNAME}:" >success_openvpn.log
echo "${PROGNAME}:" >error_openvpn.log
#
############################################################# 
#
# [EN] Function for 3 - zabbix agent / [ES] Función para 3 - agente de zabbix
#
zbx_agn () {
echo -e -n "[EN] Do you want to enable this server as a ZABBIX AGENT? / [ES] ¿Desea habilitar este servidor como AGENTE de ZABBIX? \n[Y/n]: "
read
if [[ $REPLY == "y" ]] || [[ $REPLY == "Y" ]]
then
    apt -qq install zabbix-agent fping -y 1>>success_openvpn.log 2>>error_openvpn.log
    cd /etc/zabbix 1>>success_openvpn.log 2>>error_openvpn.log
    cp zabbix_agentd.conf zabbix_agentd--.conf 1>>success_openvpn.log 2>>error_openvpn.log
#
    zabbix_ip () {
        echo -n "[EN] Zabbix Server IP / [ES] IP del Servidor de Zabbix : "
        read $ZS
    }
#
    zabbix_ip
    fping $ZS 1>>success_openvpn.log 2>>error_openvpn.log
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
# [EN] For OpenVPN, extracted from https://github.com/Grifagor/zabbix-openvpn/blob/master/zabbix_agentd.txt / [ES] Para OpenVPN, extraído de https://github.com/Grifagor/zabbix-openvpn/blob/master/zabbix_agentd.txt
UserParameter=discovery.openvpn,/etc/zabbix/scripts/discover_vpn.sh
UserParameter=user_status.openvpn[*], cat /var/log/openvpn-status.log | grep $1, >/dev/null && echo 1 || echo 0
UserParameter=num_user.openvpn, cat /var/log/openvpn-status.log | sed -n '/Connected Since/,/ROUTING/p' | sed -e '1d' -e '$d' | wc -l
UserParameter=user_byte_received.openvpn[*], if [ "`grep -c $1, /var/log/openvpn-status.log`" != "0" ]; then cat /var/log/openvpn-status.log | grep $1, | tr "," "\n" | sed -n '3p' ; else echo "0" ; fi
UserParameter=user_byte_sent.openvpn[*], if [ "`grep -c $1, /var/log/openvpn-status.log`" != "0" ]; then cat /var/log/openvpn-status.log | grep $1, | tr "," "\n" | sed -n '4p' ; else echo "0" ; fi

UserParameter=discovery.openvpn.ipp,/etc/zabbix/scripts/discover_vpn_ipp.sh # for discovery with ifconfig-pool-persist
EOL
#
    service zabbix-agent restart 1>>success_openvpn.log 2>>error_openvpn.log
#
    mkdir /etc/zabbix/scripts 1>>success_openvpn.log 2>>error_openvpn.log
    cd /etc/zabbix/scripts 1>>success_openvpn.log 2>>error_openvpn.log
    wget -q https://raw.githubusercontent.com/Grifagor/zabbix-openvpn/master/discover_vpn_ipp.sh 1>>success_openvpn.log 2>>error_openvpn.log
cat << 'EOL' > discover_vpn.sh
#!/bin/bash
# This is a modification from https://github.com/Grifagor/zabbix-openvpn/blob/master/discover_vpn.sh
path=/etc/ssl/certs # path to certificate directory

users=`ls -F $path | sed 's/\///g'` # array of certificate name

echo "{"
echo "\"data\":["

comma=""
for user in $users
do
    echo "    $comma{\"{#VPNUSER}\":\"$user\"}"
    comma=","
done

echo "]"
echo "}"

EOL
fi
}
#
#############################################################
#
# 1.
clear
OS=`grep ID_LIKE /etc/os-release | cut -c9-`
OSV=`grep VERSION_CODENAME /etc/os-release | cut -c18-`
#
#
# 2. apt / dnf
if [[ $OS == *"buntu"* ]] || [[ $OS == *"ebian"* ]]
then
    apt -qq update 1>>success_openvpn.log 2>>error_openvpn.log
    apt -qq -y install ca-certificates wget net-tools gnupg 1>>success_openvpn.log 2>>error_openvpn.log
    wget -qO - https://as-repository.openvpn.net/as-repo-public.gpg | apt-key add - 
    echo "deb http://as-repository.openvpn.net/as/debian $OSV main" > /etc/apt/sources.list.d/openvpn-as-repo.list
    apt -qq update && apt -qq -y install openvpn-as 1>>success_openvpn.log 2>>error_openvpn.log
#
    passwd openvpn
#
    wget -q https://curl.haxx.se/ca/cacert-2020-01-01.pem 1>>success_openvpn.log 2>>error_openvpn.log
    mv cacert-2020-01-01.pem /etc/ssl/certs 1>>success_openvpn.log 2>>error_openvpn.log
#
    zbx_agn
# [EN] End / [ES] Fin
    echo "[EN] Installation finished! / [ES] ¡Instalación acabada!"
elif [[ $OS == *"edora"* ]]
then
    echo "[EN] This script is ONLY for Debian based OS / [ES] Este script es SOLO para sistemas operativos basados en Debian "
fi
