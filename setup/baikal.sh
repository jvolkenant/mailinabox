#!/bin/bash
# ----------------------

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

# ### Installing Baikal
echo "Installing Baikal (Calendar/Contacts)..."
apt_install \
	php${PHP_VER}-curl php${PHP_VER}-mbstring php${PHP_VER}-xml php${PHP_VER}-sqlite3


VERSION='0.9.5'
HASH='1ddd08f757b301f25f833658d66d5be74fbf192b'

needs_update=0 #NODOC
if [ ! -f /usr/local/lib/baikal/version ]; then
	needs_update=1 #NODOC
elif [[ "$VERSION" != $(cat /usr/local/lib/baikal/version) ]]; then
	needs_update=1 #NODOC
fi
if [ $needs_update == 1 ]; then

    wget_verify \
        https://github.com/sabre-io/Baikal/releases/download/${VERSION}/baikal-${VERSION}.zip
		$HASH \
		/tmp/baikal.zip

	# Extract into place.
	rm -rf /usr/local/lib/baikal
	unzip -q /tmp/baikal.zip -d /usr/local/lib/baikal
	rm -f /tmp/baikal.zip
    echo $VERSION > /usr/local/lib/baikal/version
fi

mkdir -p $STORAGE_ROOT/baikal

chown -R www-data:www-data /usr/local/lib/baikal $STORAGE_ROOT/baikal



# https://stackoverflow.com/questions/22020754/cant-get-baikal-running-in-a-subdirectory
# base_uri: 'baikal'