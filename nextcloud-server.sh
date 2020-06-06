#!/bin/bash
# 
#   Author/Autor: Carlos Mena.
#   https://github.com/carlosm00
#
#############################################################
#
# [EN] THIS SCRIPT INSTALLS NEXTCLOUD + APACHE2 + PHP + POSTGRESQL + (OPTIONAL) ZABBIX AGENT. ONLY FOR DEBIAN BASED OS. MUST BE EXECUTED AS ROOT.
#   1. OS and release discovery
#   2. Packages installation
#   3. Configuration
#   4. (Optional) Zabbix agent
#
# [ES] ESTE SCRIPT INSTALA NEXTCLOUD + APACHE2 + PHP + POSTGRESQL + (OPCIONAL) ZABBIX AGENT. SÓLO PARA SO BASADO EN DEBIAN. DEBE SER EJECUTADO COMO ROOT.
#   1. Descubrimiento de OS y versión
#   2. Instalación de paquetes
#   3. Configuración
#   4. (Opcional) Agente de Zabbix
#
# logs
PROGNAME=$(basename $0)
echo "${PROGNAME}:" >success_nextcloud.log
echo "${PROGNAME}:" >error_nextcloud.log
#
#############################################################
#
# [EN] Function for 3 - configuration / [ES] Función para 3 - configuración
#
conf () {
clear
echo -n "[EN] Write your domain / [Es] Escriba su dominio : "
read DOM
echo $DOM | grep "." >> success_nextcloud.log
if [ $? != 0 ]
then
    echo "[EN] Your domain name must contain at least a dot / [ES] Su dominio debe contener mínimo un punto " 
    echo "Example/Ejemplo: example.com "
    echo -n "[EN] Write your domain / [Es] Escriba su dominio : "
    read DOM
fi
echo "127.0.0.1    $DOM" >> /etc/hosts
# [EN] Link to NextCloud directory / [ES] Enlace a directorio NextCloud
sudo ln -s /nas/data/nextcloud /var/www/nextcloud 1>>success_nextcloud.log 2>>error_nextcloud.log
sudo chown -R www-data:www-data /nas/data/nextcloud 1>>success_nextcloud.log 2>>error_nextcloud.log
# [EN] Database and database user creattion/ [ES] Creación de base de datos y usuario de base de datos
echo -n "[EN] Write your db user / [ES] Escriba su usuario de base de datos : "
read DB_USER
echo -n "[EN] Write your db user password / [ES] Escriba la contraseña del usuario de base de datos : "
read DB_PS
echo "create user "$DB_USER" password '"$DB_PS"';" > psql_db_nextcloud.sql
echo "create database nextcloud;" >> psql_db_nextcloud.sql
DB_PS=0
chmod 770 psql_db_nextcloud.sql 1>>success_nextcloud.log 2>>error_nextcloud.log
chown postgres:postgres psql_db_nextcloud.sql 1>>success_nextcloud.log 2>>error_nextcloud.log
sudo -u postgres psql -f psql_db_nextcloud.sql 1>>success_nextcloud.log 2>>error_nextcloud.log
if [ $? == 0 ]
then
    echo "[EN] Databse created / [ES] Base de datos creada "
else
    echo "[EN] Could not create databse / [ES] No se pudo crear la base de datos"
fi
rm psql_db_nextcloud.sql 1>>success_nextcloud.log 2>>error_nextcloud.log
# [EN] Apache's Virtual Host/ [ES] Virtual Host de Apache
cat << EOL > /etc/apache2/sites-available/$DOM.conf
<VirtualHost *:80>
ServerName $DOM
ServerAlias www.$DOM
ServerAdmin administrador@$DOM
DocumentRoot /var/www/nextcloud

<Directory /var/www/nextcloud>
    AllowOverride None
</Directory>
</VirtualHost>
EOL
# [EN] ServerName property / [ES] Propiedad de ServerName
if [ ! $(grep ServerName /etc/apache2/apache2.conf) ]
then
    echo "ServerName "$DOM >> /etc/apache2/apache2.conf
fi
# [EN] Validation / [ES] Validación
a2dissite 000-default.conf 1>>success_nextcloud.log 2>>error_nextcloud.log
a2ensite $DOM.conf 1>>success_nextcloud.log 2>>error_nextcloud.log
systemctl restart apache2 1>>success_nextcloud.log 2>>error_nextcloud.log
# HTTPS
echo -e -n "[EN] Do you want to enable HTTPS? / [ES] ¿Desea habilitar HTTPS? \n[Y/n]: "
read
if [[ $REPLY == "y" ]] || [[ $REPLY == "Y" ]]
then
    apt -qq -y install software-properties-common 1>>success_nextcloud.log 2>>error_nextcloud.log
    apt -qq update 1>>success_nextcloud.log 2>>error_nextcloud.log
    add-apt-repository ppa:certbot/certbot -y 1>>success_nextcloud.log 2>>error_nextcloud.log
    apt -qq install python-certbot-apache -y 1>>success_nextcloud.log 2>>error_nextcloud.log
    clear
    certbot --apache -d $DOM
fi
# [EN] Comprobation / [ES] Comprobación
HTTPS_STATUS=$(curl -I https://$DOM | grep "HTTP/2 200" | head -n 1)
if [ ! -z "$HTTPS_STATUS" ]
then
    echo -e "[EN] HTTPS enabled on your site / [ES] HTTPS habilitado en tu sitio \n --> https://nextcloud.$DOM \n"
else
    HTTP_STATUS=$(curl -I http://$DOM | grep "HTTP/2 200" | head -n 1)
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
zbx_agn () {
echo -e -n "[EN] Do you want to enable this server as a ZABBIX AGENT? / [ES] ¿Desea habilitar este servidor como AGENTE de ZABBIX? \n[Y/n]: "
read
if [[ $REPLY == "y" ]] || [[ $REPLY == "Y" ]]
then
    apt -qq install zabbix-agent fping -y 1>>success_nextcloud.log 2>>error_nextcloud.log
    cd /etc/zabbix 1>>success_nextcloud.log 2>>error_nextcloud.log
    cp zabbix_agentd.conf zabbix_agentd--.conf 1>>success_nextcloud.log 2>>error_nextcloud.log
#
    zabbix_ip () {
        echo -n "[EN] Zabbix Server IP / [ES] IP del Servidor de Zabbix : "
        read $ZS
    }
#
    zabbix_ip
    fping $ZS 1>>success_nextcloud.log 2>>error_nextcloud.log
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
# [EN] This are the configuration steps for https://github.com/y-u-r/nextcloud-zabbix template / [ES] Estos son los pasos de configuración para la plantilla de https://github.com/y-u-r/nextcloud-zabbix
    cd /etc/zabbix/zabbix_agentd.conf.d 1>>success_nextcloud.log 2>>error_nextcloud.log
    echo 'UserParameter=nextcloud[*],curl -s https://api:"$2"@'$DOM'/ocs/v2.php/apps/serverinfo/api/v1/info | grep "$1" | cut -d "<" -f 2 | cut -d ">" -f 2 | head -n 1' > nextcloud.conf
    service zabbix-agent restart 1>>success_nextcloud.log 2>>error_nextcloud.log
fi
}
#
############################################################# EXECUTION / EJECUCIÓN ##################################
#
# 1.
clear
OS=`grep ID_LIKE /etc/os-release | cut -c9-`
#
#
# 2. apt / dnf
if [[ $OS == *"buntu"* ]] || [[ $OS == *"ebian"* ]]
then
    apt -qq update 1>>success_nextcloud.log 2>>error_nextcloud.log
    apt -qq install -y unzip wget php apache2 php-zip php-pgsql php-mbstring php-gd php-ldap php-curl postgresql php-xml php-dom 1>>success_nextcloud.log 2>>error_nextcloud.log
    mkdir -p /nas/data/nextcloud 1>>success_nextcloud.log 2>>error_nextcloud.log
    cd /nas/data/ 1>>success_nextcloud.log 2>>error_nextcloud.log
    wget -q https://download.nextcloud.com/server/releases/nextcloud-18.0.4.zip 1>>success_nextcloud.log 2>>error_nextcloud.log
    unzip nextcloud-18.0.4.zip 1>>success_nextcloud.log 2>>error_nextcloud.log
    rm nextcloud-18.0.4.zip 1>>success_nextcloud.log 2>>error_nextcloud.log
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
