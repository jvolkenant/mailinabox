#!/bin/bash

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars
touch /etc/mailinabox.conf.custom
source /etc/mailinabox.conf.custom # load custom global vars

: ${SOLR:-} # should be full path including ending slash, i.e. https://solr.blah.com:8983/solr/dovecot/

echo "Installing Dovecot Solr FTS support..."

if [[ -z "${SOLR}" ]]; then
   echo "Please set SOLR variable in /etc/mailinabox.conf.custom to the path of your SOLR instance"
fi


apt_install dovecot-solr

# add mail plugin early in the configs
tools/editconf.py /etc/dovecot/conf.d/10-mail.conf \
        mail_plugins="\$mail_plugins fts fts_solr"

# Solr config
cat <<EOF > /etc/dovecot/conf.d/90-fts.conf
plugin {
    fts = solr
    fts_solr = url=${SOLR}
}
EOF

restart_service dovecot

# Tell dovecot to check with solr and sync the indexes for all mailboxes
doveadm fts rescan -A

# This forces a reindex of all mailboxes
# doveadm index -q -A '*'

# Cron
cat <<EOF > /etc/cron.d/solr
# Optimize should be run somewhat rarely, e.g. once a day
@daily root curl ${SOLR}update?optimize=true >/dev/null 2>&1
# Commit should be run pretty often, e.g. every minute
*/5 * * * * root curl ${SOLR}update?commit=true >/dev/null 2>&1
EOF