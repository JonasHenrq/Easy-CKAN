clear
echo    "# ======================================================== #"
echo    "# == Easy CKAN installation for Ubuntu 16.04            == #"
echo    "#                                                          #"
echo    "# Special thanks to:                                       #"
echo    "#   Alerson Luz (GitHub: alersonluz)                       #"
echo    "#   Adrien GRIMAL                                          #"
echo    "# ======================================================== #"
#su -c "sleep 3"

# DEBUG!!!!!!!!!!!!!!!!!!!!!!!!!!!
if [ ! -d "/var" ]; then

# Get parameters from user
# ==============================================
echo    ""
echo    "# ======================================================== #"
echo    "# == 1. Set main config variables                       == #"
echo    "# ======================================================== #"
echo    ""

# No arguments sent. Interactive input.
if [ -z "$1" ] || [ -z "$2" ]; then
	echo    "# 1.1. Set site URL"
	echo    "| You site URL must be like http://localhost"
	echo -n "| Type the domain: http://"
	read v_siteurl

	echo    ""
	echo    "# 1.2. Set Password PostgreSQL (database)"
	echo    "| Enter a password to be used on installation process. "
	echo -n "| Type a password: "
	read v_password

# Set from arguments
else
	v_siteurl=$1
	v_password=$2
fi


# Preparations
# ==============================================
echo    ""
echo    "# ======================================================== #"
echo    "# == 2. Update Ubuntu packages                          == #"
echo    "# ======================================================== #"
su -c "sleep 2"
cd /tmp
apt-get update


# Docker
# ==============================================
echo    ""
echo    "# ======================================================== #"
echo    "# == 3. Install Docker                                  == #"
echo    "# ======================================================== #"
curl -sSL https://get.docker.com/ | sh
usermod -aG docker $(grep 1000 /etc/passwd | cut -f1 -d:)


# Main dependences
# ==============================================
echo    ""
echo    "# ======================================================== #"
echo    "# == 3. Install CKAN dependences from 'apt-get'         == #"
echo    "# ======================================================== #"
su -c "sleep 2"
apt-get install -y python-dev libpq-dev python-pip python-virtualenv git-core openjdk-8-jdk sudo
if [ ! -d "/usr/java" ]; then
	# Create link to Java JDK on default path
	mkdir /usr/java
	ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/java/default
fi


# DEBUG!!!!!!!!!!!!!!!!!!!!!!!!!!!
fi


# Setup a PostgreSQL database
# ==============================================
echo    ""
echo    "# ======================================================== #"
echo    "# == 3. Docker: Setup PostgreSQL container              == #"
echo    "# ======================================================== #"

# Set variables
v_docker_postgres_path="/var/easyckan/database"							# Host persistent data path
v_docker_postgres_name="ckan-postgres"									# Container name
v_docker_postgres_v="$v_docker_postgres_path:/var/lib/postgresql/data"	# Volume path
v_docker_postgres_p="5432:5432"											# Port
v_docker_postgres_i="postgres:9.6.2"									# Image and tag

# Remove old container if exists
if [ ! "$(docker ps -q -f name=$v_docker_postgres_name)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=$v_docker_postgres_name)" ]; then
        # cleanup
        docker rm $v_docker_postgres_name
    fi
fi

# Create persistent data dir
mkdir -p $v_docker_postgres_path

# Create container as daemon
docker run --name $v_docker_postgres_name -v $v_docker_postgres_v -e POSTGRES_PASSWORD=$v_password -p $v_docker_postgres_p -d $v_docker_postgres_i
	   

exit



# HARD FIX POSTGRES
service postgresql restart

su postgres -c "psql -c \"update pg_database set datallowconn = TRUE where datname = 'template0';\""

su postgres -c "psql -d template0 -c \"update pg_database set datistemplate = FALSE where datname = 'template1';\""
su postgres -c "psql -d template0 -c \"drop database template1;\""
su postgres -c "psql -d template0 -c \"create database template1 with template = template0 encoding = 'UTF8';\""
su postgres -c "psql -d template0 -c \"update pg_database set datistemplate = TRUE where datname = 'template1';\""

su postgres -c "psql -d template1 -c \"update pg_database set datallowconn = FALSE where datname = 'template0';\""
# HARD FIX POSTGRES


#echo    "| Insert the SAME password two more times..."
#: $(su postgres -c "createuser -S -D -R -P ckan_default")
su postgres -c "psql --command \"CREATE USER ckan_default WITH PASSWORD '"$v_password"';\""
su postgres -c "createdb -O ckan_default ckan_default -E utf-8"






# Setup CKAN
# ==============================================
echo    ""
echo    ""
echo    "# ======================================================== #"
echo    "# == 4. Setup CKAN                                      == #"
echo    "# ======================================================== #"
su -c "sleep 2"

# Create user
echo    "# 4.1. Creating CKAN user..."
useradd -m -s /sbin/nologin -d /usr/lib/ckan -c "CKAN User" ckan
sudo usermod -a -G staff ckan
chmod 775 -R /usr/local/lib/python2.7
chmod 755 /usr/lib/ckan
chown ckan.33 -R /usr/lib/ckan

# Python Virtual Environment
echo    "# 4.2. Creating Python Virtual Environment..."
su -c "sleep 2"
apt-get install -y  python-paste
su -s /bin/bash - ckan -c "mkdir -p /usr/lib/ckan/default"
su -s /bin/bash - ckan -c "virtualenv --no-site-packages /usr/lib/ckan/default"
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && pip install --upgrade pip"		# HARD FIX
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && pip install setuptools==20.4"	# HARD FIX for CKAN 2.6.0
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && pip install html5lib==0.999"		# HARD FIX

# Installing CKAN and dependences
echo    "# 4.3. Installing CKAN and dependences..."
apt-get install -y libmemcached-dev zlib1g-dev # FIX for CKAN 2.6.0
su -c "sleep 2"
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.6.2#egg=ckan'"
sed -i "s/bleach==1.4.2/bleach==1.4.3/g" /usr/lib/ckan/default/src/ckan/requirements.txt # HOT FIX
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && pip install -r /usr/lib/ckan/default/src/ckan/pip-requirements-docs.txt"




# Create main CKAN config files
echo    "# 4.4. Creating main configuration file at /etc/ckan/default/development.ini ..."
su -c "sleep 2"
mkdir -p /etc/ckan/default
chown -R ckan.ckan /etc/ckan
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && paster make-config ckan /etc/ckan/default/development.ini"
sed -i "s/ckan.site_url =/ckan.site_url = http:\/\/$v_siteurl/g" /etc/ckan/default/development.ini
sed -i "s/ckan_default:pass@localhost/ckan_default:$v_password@localhost/g" /etc/ckan/default/development.ini
sed -i "s/#solr_url/solr_url/g" /etc/ckan/default/development.ini
sed -i "s/127.0.0.1:8983/127.0.0.1:8080/g" /etc/ckan/default/development.ini
chown ckan.33 -R /etc/ckan/default

# Setup a storage path
echo    "# 4.5 Setting a storage path for upload support..."
su -c "sleep 2"
mkdir -p /var/lib/ckan
chown -R ckan.33 /var/lib/ckan
sed -i 's/#ckan.storage_path/ckan.storage_path/g' /etc/ckan/default/development.ini






# Install Solr
# ==============================================
echo    ""
echo    ""
echo    "# ======================================================== #"
echo    "# == 5. Install Apache Solr                             == #"
echo    "# ======================================================== #"
su -c "sleep 2"
echo    "# 5.1. Installing from 'apt-get'..."
apt-get -y install solr-tomcat
mv /etc/solr/conf/schema.xml /etc/solr/conf/schema.xml.bak
cp /usr/lib/ckan/default/src/ckan/ckan/config/solr/schema.xml /etc/solr/conf/schema.xml

# Restarting services
echo    "# 5.2. Restarting Solr..."
service tomcat7 restart





# Last configurations
# ==============================================
echo    ""
echo    ""
echo    "# ======================================================== #"
echo    "# == 6. Finishing                                       == #"
echo    "# ======================================================== #"
su -c "sleep 2"

# HARD FIX POSTGRES
service postgresql restart

su postgres -c "psql -c \"update pg_database set datallowconn = TRUE where datname = 'template0';\""

su postgres -c "psql -d template0 -c \"update pg_database set datistemplate = FALSE where datname = 'template1';\""
su postgres -c "psql -d template0 -c \"drop database template1;\""
su postgres -c "psql -d template0 -c \"create database template1 with template = template0 encoding = 'UTF8';\""
su postgres -c "psql -d template0 -c \"update pg_database set datistemplate = TRUE where datname = 'template1';\""

su postgres -c "psql -d template1 -c \"update pg_database set datallowconn = FALSE where datname = 'template0';\""
service postgresql restart
# HARD FIX POSTGRES

echo    "# 6.1. Initilize CKAN database..."
service tomcat7 restart
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && cd /usr/lib/ckan/default/src/ckan && paster db init -c /etc/ckan/default/development.ini"

echo    "# 6.2. Set 'who.ini'..."
ln -s /usr/lib/ckan/default/src/ckan/who.ini /etc/ckan/default/who.ini

echo    "# 6.3. Enable Tomcat6 and PostgreSQL on startup..."
sudo update-rc.d postgresql enable
sudo update-rc.d tomcat7 enable





# Create a admin account
# ==============================================
clear
echo    "# ======================================================== #"
echo    "# == 7. CKAN Account                                    == #"
echo    "# ======================================================== #"
su -c "sleep 2"

echo    "# 7.1 Creating a Admin account..."
echo    "| Your account name will be 'admin'."
echo    "| Type the admin password:"
su -s /bin/bash - ckan -c ". /usr/lib/ckan/default/bin/activate && cd /usr/lib/ckan/default/src/ckan && paster sysadmin add admin -c /etc/ckan/default/development.ini"



# PLUGINS
#
# Just if installation doesn't have args
# ==============================================
if [ -z "$1" ] || [ -z "$2" ]; then
	echo    ""
	echo    ""
	echo    "# ======================================================== #"
	echo    "# == Plugins (optional)                                 == #"
	echo    "# ======================================================== #"
	su -c "sleep 2"

	# PLUGIN Harvest Installer
	echo    "# PLUGIN Harvest"
	echo -n "# You want to install? [y/N]: "
	read plugin_harvest
	if [[ $plugin_harvest == "y" ]]
	then
		su -c "easyckan plugin install harvest"
	fi

	# PLUGIN DataStore Installer
	echo    "# PLUGIN DataStore"
	echo -n "# You want to install? [y/N]: "
	read plugin_datastore
	if [[ $plugin_datastore == "y" ]]
	then
		su -c "easyckan plugin install datastore"
	fi
	echo    ""
fi




su -c "sleep 2"
echo    ""
echo    "# ======================================================== #"
echo    "# == CKAN installation complete!                        == #"
echo    "# ======================================================== #"
echo    "|"
echo    "# Press [Enter] to continue..."
read success