all:

# ------ Setup ------

WGET = wget
GIT = git

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

local-perl: pmbp-install

pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl

pmbp-update: pmbp-upgrade
	perl local/bin/pmbp.pl --update

pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
	    --create-perl-command-shortcut perl \
	    --create-perl-command-shortcut prove \
	    --create-perl-command-shortcut plackup

git-submodules:
	$(GIT) submodule update --init

deps: pmbp-install

always:

# ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps
	cd modules/rdb-utils && $(MAKE) deps

test-main:
	HOME="$(abspath local/home)" $(PROVE) t/*.t t/cmd/*.t

# ------ Local (example) ------

LOCAL_SERVER_ARGS = \
	    APP_NAME=dango \
	    SERVER_INSTANCE_NAME=dangolocal \
	    SERVER_PORT=6026 \
	    SERVER_ENV=default \
	    ROOT_DIR="$(abspath .)" \
	    SERVICE_DIR="/etc/service"

local-server:
	$(MAKE) --makefile=Makefile.service all $(LOCAL_SERVER_ARGS) \
	    SERVER_TYPE=web

install-local-server:
	$(MAKE) --makefile=Makefile.service install $(LOCAL_SERVER_ARGS) \
	    SERVER_TYPE=web

autoupdatenightly:
