#!/bin/bash

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

echo "Installing Dovecot Solr FTS support..."

if [[ -z "${SOLR}" ]]; then
   input_box "Solr URL" \
				"Solr URL?\nThis should be the full path including ending slash.\nExample: http://solr:8983/solr/dovecot/" \
				"" \
				SOLR

    if [[ $SOLR == http* ]]; then
        echo "SOLR=\"$SOLR\"" >> /etc/mailinabox.conf
    else
        echo "Invalid Solr URL. A valid url looks like \"http://solr:8983/solr/dovecot/\""
        echo "You entered: $SOLR"
        exit 1
    fi
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
    fts_autoindex = yes
    fts_enforced = yes
    fts_autoindex_exclude = \\Trash
    fts_decoder = decode2text
}

service decode2text {
    executable = script /usr/libexec/dovecot/decode2text.sh
    user = dovecot
    unix_listener decode2text {
        mode = 0666
    }
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
