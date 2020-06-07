#!/bin/bash
# 
#   Author/Autor: Carlos Mena.
#   https://github.com/carlosm00
#
#############################################################
#
# [EN] THIS SCRIPT INSTALLS ZABBIX SERVER + APACHE2 + PHP + POSTGRESQL + (OPTIONAL) ZABBIX TEMPLATES. ONLY FOR DEBIAN BASED OS. MUST BE EXECUTED AS ROOT.
#   1. OS and release discovery
#   2. Packages installation
#   3. Configuration
#   4. (Optional) Zabbix templates for other services
#
# [ES] ESTE SCRIPT INSTALA ZABBIX SERVER + APACHE2 + PHP + POSTGRESQL + (OPCIONAL) PLNATILLAS DE ZABBIX. SÓLO PARA SO BASADO EN DEBIAN. DEBE SER EJECUTADO COMO ROOT.
#   1. Descubrimiento de OS y versión
#   2. Instalación de paquetes
#   3. Configuración
#   4. (Opcional) Plantillas de Zabbix para otros servicios
#
# logs
PROGNAME=$(basename $0)
mkdir /tmp/zabbix_installation
echo "${PROGNAME}:" >/tmp/zabbix_installation/success_ldap.log
echo "${PROGNAME}:" >/tmp/zabbix_installation/error_ldap.log
#
#############################################################
#
# [EN] Function for 3 - configuration / [ES] Función para 3 - configuración
#
conf () {
echo -n "[EN] Write your db user / [ES] Escriba su usuario de base de datos : "
read DB_USER
echo -n "[EN] Write your db user password / [ES] Escriba la contraseña del usuario de base de datos : "
read DB_PS
echo "create user "$DB_USER" password '"$DB_PS"';" > psql_db_zabbix.sql
echo "create database zabbix;" >> psql_db_zabbix.sql
chmod 770 psql_db_zabbix.sql 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
chown postgres:postgres psql_db_zabbix.sql 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
sudo -u postgres psql -f psql_db_zabbix.sql 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
if [ $? == 0 ]
then
    echo "[EN] Databse created / [ES] Base de datos creada "
else
    echo "[EN] Could not create databse / [ES] No se pudo crear la base de datos"
fi
rm psql_db_zabbix.sql 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
# [EN] Zabbix schema on postgresql databse / [ES] Esquema de Zabbix en la base de datos de postgresql
zcat /usr/share/doc/zabbix-server-pgsql/create.sql.gz | sudo -u zabbix psql zabbix 
# [EN] Backup for zabbix server config file / [ES] Copia de seguridad del archivo ed configuración del servidor de zabbix
cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server-.conf 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
# [EN] / [ES]
cat << EOL > /etc/zabbix/zabbix_server.conf
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
DebugLevel=3
PidFile=/var/run/zabbix/zabbix_server.pid
SocketDir=/var/run/zabbix
DBHost=localhost
DBName=zabbix
DBUser=$DB_USER
DBPassword=$DB_PS
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=4
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts
FpingLocation=/usr/bin/fping
Fping6Location=/usr/bin/fping6
LogSlowQueries=3000
EOL
DB_PS=0
# [EN] Redirection to zabbix home page / [ES] Redirección a la página principal de zabbix
echo -n "[EN] Write your domain / [Es] Escriba su dominio : "
read DOM
echo $DOM | grep "." >>/tmp/zabbix_installation/success_zabbix.log
if [ $? != 0 ]
then
    echo "[EN] Your domain name must contain at least a dot / [ES] Su dominio debe contener mínimo un punto "
    echo "Example/Ejemplo: example.com "
    echo -n "[EN] Write your domain / [Es] Escriba su dominio : "
    read DOM
fi
cat << EOL > /var/www/html/index.html
<!DOCTYPE html>
<html>
   <head>
      <title> ZABBIX </title>
      <meta http-equiv = "refresh" content = "0; url = http://$DOM/zabbix" />
   </head>
   <body>
   </body>
</html>
EOL
# [EN] Service restart / [ES] Reinicio de los servicios
service zabbix-server start 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
update-rc.d zabbix-server enable 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
# [EN] Timezone for zabbix frontend / [ES] Zona Temporal en el frontend de zabbix
echo "php_value date.timezone Europe/Madrid" >> /etc/zabbix/apache.conf
service apache2 restart 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
# HTTPS
echo -e -n "[EN] Do you want to enable HTTPS? / [ES] ¿Desea habilitar HTTPS? \n[Y/n]: "
read
if [[ $REPLY == "y" ]] || [[ $REPLY == "Y" ]]
then
    apt -qq -y install software-properties-common 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    apt -qq update 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    add-apt-repository ppa:certbot/certbot -y 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    apt -qq install python-certbot-apache -y 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    certbot --apache -d $DOM
fi
# [EN] Comprobation / [ES] Comprobación
HTTPS_STATUS=$(curl -I https://$DOM/zabbix | grep "HTTP/2 200" | head -n 1)
if [ ! -z "$HTTPS_STATUS" ]
then
    echo -e "[EN] HTTPS enabled on your site / [ES] HTTPS habilitado en tu sitio \n --> https://nextcloud.$DOM \n"
else
    HTTP_STATUS=$(curl -I http://$DOM/zabbix | grep "HTTP/2 200" | head -n 1)
    if [ ! -z "$HTTP_STATUS" ]
    then
        echo -e "[EN] HTTPS NOT enabled on your site (but still working with HTTP) / [ES] HTTPS NO habilitado en tu sitio (pero sigue funcionando con HTTP) \n --> http://nextcloud.$DOM \n"
    else
        echo "[EN] There was a problem with your site... / [ES] Ha habido un problema con su sitio... "
    fi
fi
}
#
############################################################# 
#
# [EN] Function for 4 - zabbix agent / [ES] Función para 4 - agente de zabbix
#
zbx_tem () { 
echo -e -n "[EN] Do you want to download zabbix templates? / [ES] ¿Desea descargar plantillas de zabbix? \n[Y/n]: "
read
if [[ $REPLY == "y" ]] || [[ $REPLY == "Y" ]]
then
    echo -e -n "[EN] Available templates / [ES] Plantillas disponibles \n    1. Nextcloud (by y-u-r)\n    2. OpenLDAP (by MrCirca)\n    3. OpenVPN (by Grifagor)\n [EN] Please write the number of the templates you want to download or 'a' for all / [ES] Por favor, escriba el número de las plantillas que desea descargar o 'a' para todas : "
    read DZ
    if [[ ! -z $( echo $DZ | grep "1") ]]
    then
        mkdir -p /tmp/zabbix 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        cd /tmp/zabbix 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        wget -q https://raw.githubusercontent.com/y-u-r/nextcloud-zabbix/master/zbx_export_templates.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        chmod 775 zbx_export_templates.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    fi
    if [[ ! -z $( echo $DZ | grep "2") ]]
    then
        mkdir -p /tmp/zabbix 1>>success_zabbix.log 2>>error_zabbix.log
        cd /tmp/zabbix 1>>success_zabbix.log 2>>error_zabbix.log
        wget -q https://raw.githubusercontent.com/MrCirca/OpenLDAP-Cluster-Zabbix/master/zabbix_openldap_template.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        wget -q https://raw.githubusercontent.com/MrCirca/OpenLDAP-Cluster-Zabbix/master/zabbix_openldap_value_mapping.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        chmod 775 zabbix_openldap_template.xml zabbix_openldap_value_mapping.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    fi
    if [[ ! -z $( echo $DZ | grep "3") ]]
    then
        mkdir -p /tmp/zabbix 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        cd /tmp/zabbix 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        wget -q https://raw.githubusercontent.com/Grifagor/zabbix-openvpn/master/openvpn.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        chmod 775 openvpn.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    fi
    if [ $DZ == "a" ]
    then
        mkdir -p /tmp/zabbix 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        cd /tmp/zabbix 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        wget -q https://raw.githubusercontent.com/y-u-r/nextcloud-zabbix/master/zbx_export_templates.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        wget -q https://raw.githubusercontent.com/MrCirca/OpenLDAP-Cluster-Zabbix/master/zabbix_openldap_template.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        wget -q https://raw.githubusercontent.com/MrCirca/OpenLDAP-Cluster-Zabbix/master/zabbix_openldap_value_mapping.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        wget -q https://raw.githubusercontent.com/Grifagor/zabbix-openvpn/master/openvpn.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
        chmod 775 *.xml 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    fi
fi
}
#
############################################################# EXECUTION / EJECUCIÓN ##################################
#
# 1.
clear
OSI=`grep ID= /etc/os-release | cut -c4- | head -n 1`
OS=`grep ID_LIKE /etc/os-release | cut -c9-`
OSV=`grep VERSION_CODENAME /etc/os-release | cut -c18-`
#
#
# 2. apt / dnf
if [[ $OS == *"buntu"* ]] || [[ $OS == *"ebian"* ]]
then
    apt -qq update 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    apt -qq install -y apache2 postgresql php php-mbstring php-gd php-xml php-bcmath php-ldap php-pgsql 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    wget -q https://repo.zabbix.com/zabbix/4.0/$OSI/pool/main/z/zabbix-release/zabbix-release_4.0-3+${OSV}_all.deb 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    dpkg -i zabbix-release_4.0-3+${OSV}_all.deb 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    apt update 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
    apt install zabbix-server-pgsql zabbix-frontend-php zabbix-agent -y 1>>/tmp/zabbix_installation/success_zabbix.log 2>>/tmp/zabbix_installation/error_zabbix.log
# [EN] Execution function for 3 / [ES] Ejecución de función para 3
    conf
# [EN] Execution function for 4 / [ES] Ejecución de función para 4
    zbx_tem 
# [EN] End / [ES] Fin
    echo "[EN] Installation finished! / [ES] ¡Instalación acabada!"
elif [[ $OS == *"edora"* ]]
then
    echo "[EN] This script is ONLY for Debian based OS / [ES] Este script es SOLO para sistemas operativos basados en Debian "
fi
