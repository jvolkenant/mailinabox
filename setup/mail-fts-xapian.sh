#!/bin/bash
# ### Full text search (FTS-XAPIAN)

# Dovecot on Ubuntu 14.04 had a built in lucene mail search, that was
# removed in Ubuntu 18.04. Compared to other FTS, this one is simple
# and might require less ram than Solr (to be tested)

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

echo "Installing FTS-Xapian (Email Full Text Search)..."


# Install dovecot-fts-xapian and tools needed for decode2text.sh
apt_install dovecot-fts-xapian poppler-utils catdoc

# 90-fts.com - Full Text Search Config

# "fts_xapian = ..." options:
#       partial: Between 3 and 20, not optional
#       full: Between 3 and 20, not optional
#       verbose: 0 (silent), 1 (verbose) or 2 (debug)
#       lowmemory: 0 (default, meaning 250MB), or set value (in MB)


# Create the config file
cat <<EOF > /etc/dovecot/conf.d/90-fts.conf
mail_plugins=\$mail_plugins fts fts_xapian

plugin {
    fts = xapian
    fts_xapian = partial=3 full=20 verbose=0 lowmemory=0
    fts_autoindex = yes
    fts_enforced = yes
    fts_autoindex_exclude = \\Trash
    fts_decoder = decode2text
}

service indexer-worker {
    # Increase vsz_limit to 2GB or above.
    # Or 0 if you have rather large memory usable on your server, which is preferred for performance)
    # Dovecot will OOM if swap is too small
    vsz_limit = 2G
    # indexer-workers are background processes that are not normally visible to the end user
    # (exception: if mails are not indexed, i.e. on delivery, indexing needs to occur on-demand
    # if a user issues a SEARCH command). Therefore, they generally should be configured to a
    # lower priority to ensure that they do not steal resources from other processes that are user facing.
    # A recommendation is to execute the process at a lower priority. This can be done by prefixing the
    # executable location with a priority modifier.
    # https://doc.dovecot.org/configuration_manual/service_configuration/
    executable = /usr/bin/nice -n 10 /usr/lib/dovecot/indexer-worker
}

service decode2text {
    executable = script /usr/libexec/dovecot/decode2text.sh
    user = dovecot
    unix_listener decode2text {
        mode = 0666
    }
}
EOF

# Setup the decode2text.sh script
mkdir -p /usr/libexec/dovecot/
cp -f /usr/share/doc/dovecot-core/examples/decode2text.sh /usr/libexec/dovecot/decode2text.sh
chmod 755 /usr/libexec/dovecot/decode2text.sh

# Setup xml2text script, decode2text.sh expects this file in the same directory
ln -sf /usr/lib/dovecot/xml2text /usr/libexec/dovecot/xml2text

# Daily cron
cat <<EOF > /etc/cron.daily/mail-fts-xapian
#!/bin/bash
# Mail-in-a-Box
# Daily task for full text search
doveadm fts optimize -A
EOF

chmod 755 /etc/cron.daily/mail-fts-xapian

# Restart services.
restart_service dovecot

# Dovecot FTS engine will automatically add mail to FTS when new mail arrives.
# To force an index of all mailboxes run:
#	doveadm index -A -q \*
