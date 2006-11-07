PREFIX       =
TOP_REPOS    = ../../..
IDLDIR       = ${TOP_REPOS}/idl/trunk
INSTALL      = ./install-sh
GENZONE      = ZoneGenerator
WHOIS        = Whois

.PHONY: all build clean

all: build
	-@echo
	-@echo Type \"make install-server\" in order to install pyccreg server
	-@echo and \"make install-clients\" to install clients. Type \"make
	-@echo install\" to install both. If you decide to install only server
	-@echo or only clients do not forget to type \"make install-idl\".
	-@echo

build: $(IDLDIR)/$(GENZONE).idl $(IDLDIR)/$(WHOIS).idl
	omniidl -bpython -Wbinline ${IDLDIR}/${GENZONE}.idl ${IDLDIR}/${WHOIS}.idl

install: install-idl install-server install-clients

install-idl: build
	@echo Installing shared IDL
	$(INSTALL) -d $(PREFIX)/usr/lib/pyccReg/share
	cp -r ccReg                  $(PREFIX)/usr/lib/pyccReg/share
	cp -r ccReg__POA             $(PREFIX)/usr/lib/pyccReg/share
	$(INSTALL) $(WHOIS)_idl.py   $(PREFIX)/usr/lib/pyccReg/share
	$(INSTALL) $(GENZONE)_idl.py $(PREFIX)/usr/lib/pyccReg/share

install-server: \
		../server/pyccReg.py \
		../server/ccreg_util.py \
		../server/genzone.py \
		../server/whois.py \
		../server/pyccReg_modules.conf
	@echo Installing pyccReg server
	$(INSTALL) -d $(PREFIX)/usr/bin
	$(INSTALL) -d $(PREFIX)/usr/lib/pyccReg/server
	$(INSTALL) -d $(PREFIX)/etc
	$(INSTALL) ../server/pyccReg.py    $(PREFIX)/usr/bin
	$(INSTALL) ../server/ccreg_util.py $(PREFIX)/usr/lib/pyccReg/server
	$(INSTALL) ../server/genzone.py    $(PREFIX)/usr/lib/pyccReg/server
	$(INSTALL) ../server/whois.py      $(PREFIX)/usr/lib/pyccReg/server
	@cmp ../server/pyccReg_modules.conf $(PREFIX)/etc/pyccReg_modules.conf 2>&1 1>&/dev/null;\
	  if [ $$? -ne 1 ]; then \
	    $(INSTALL) ../server/pyccReg_modules.conf $(PREFIX)/etc;\
	    echo Config file $(PREFIX)/etc/pyccReg_modules.conf installed;\
	  else \
		echo Config file $(PREFIX)/etc/pyccReg_modules.conf not;\
		echo overwritten because of detected changes.;\
	  fi

install-clients: install-client-whois install-client-genzone

install-client-whois: ../clients/whois/whois_client.py
	@echo Installing whois client
	$(INSTALL) -d $(PREFIX)/usr/bin;
	$(INSTALL) ../clients/whois/whois_client.py $(PREFIX)/usr/bin

install-client-genzone: \
		../clients/genzone/genzone_client.py \
		../clients/genzone/genzones.sh \
		../clients/genzone/skels/genzones \
		../clients/genzone/skels/zone-prefix \
		../clients/genzone/skels/zone-postfix
	@echo Installing genzone client
	$(INSTALL) -d $(PREFIX)/usr/bin
	$(INSTALL) -d $(PREFIX)/etc/default
	$(INSTALL) -d $(PREFIX)/etc/bind
	$(INSTALL) ../clients/genzone/genzone_client.py  $(PREFIX)/usr/bin
	$(INSTALL) ../clients/genzone/genzones.sh        $(PREFIX)/usr/bin
	@cmp ../clients/genzone/genzones.sh $(PREFIX)/etc/default/genzones.sh 2>&1 1>&/dev/null;\
	  if [ $$? -ne 1 ]; then \
	    $(INSTALL) ../clients/genzone/skels/genzones $(PREFIX)/etc/default;\
	    echo Configuration file $(PREFIX)/etc/default/genzones installed;\
	  else \
	    echo Configuration file $(PREFIX)/etc/default/genzones preserved;\
	  fi
	@cmp ../clients/genzone/skels/zone-prefix $(PREFIX)/etc/bind/zone-prefix 2>&1 1>&/dev/null;\
	  if [ $$? -ne 1 ]; then \
	    $(INSTALL) ../clients/genzone/skels/zone-prefix  $(PREFIX)/etc/bind;\
	    echo Configuration file $(PREFIX)/etc/bind/zone-prefix installed;\
	  else \
	    echo Configuration file $(PREFIX)/etc/bind/zone-prefix preserved;\
	  fi
	@cmp ../clients/genzone/skels/zone-postfix $(PREFIX)/etc/bind/zone-postfix 2>&1 1>&/dev/null;\
	  if [ $$? -ne 1 ]; then \
	    $(INSTALL) ../clients/genzone/skels/zone-postfix $(PREFIX)/etc/bind;\
	    echo Configuration file $(PREFIX)/etc/bind/zone-postfix installed;\
	  else \
	    echo Configuration file $(PREFIX)/etc/bind/zone-postfix preserved;\
	  fi

uninstall: uninstall-idl uninstall-server uninstall-clients
	-rmdir  $(PREFIX)/usr/lib/pyccReg 2>/dev/null

uninstall-idl:
	@echo Uninstalling shared IDL
	-rm -f  $(PREFIX)/usr/lib/pyccReg/share/$(WHOIS)_idl.py
	-rm -f  $(PREFIX)/usr/lib/pyccReg/share/$(GENZONE)_idl.py
	-rm -rf $(PREFIX)/usr/lib/pyccReg/share/ccReg
	-rm -rf $(PREFIX)/usr/lib/pyccReg/share/ccReg__POA
	-rmdir  $(PREFIX)/usr/lib/pyccReg/share 2>/dev/null

uninstall-server:
	@echo Uninstalling pyccreg server
	-rm -f $(PREFIX)/usr/bin/pyccReg.py
	-rm -f $(PREFIX)/usr/lib/pyccReg/server/ccreg_util.py
	-rm -f $(PREFIX)/usr/lib/pyccReg/server/genzone.py
	-rm -f $(PREFIX)/usr/lib/pyccReg/server/whois.py
	-@cmp ../server/pyccReg_modules.conf $(PREFIX)/etc/pyccReg_modules.conf 2>&1 1>&/dev/null;\
	  if [ $$? -eq 0 ]; then \
		rm -f $(PREFIX)/etc/pyccReg_modules.conf;\
		echo Config file $(PREFIX)/etc/pyccReg_modules.conf deleted;\
	  else \
		echo Delete config file $(PREFIX)/etc/pyccReg_modules.conf if ;\
		echo you are not going to reinstall pyccReg server.;\
	  fi
	-rmdir $(PREFIX)/usr/lib/pyccReg/server 2>/dev/null

uninstall-clients: uninstall-client-whois uninstall-client-genzone

uninstall-client-whois:
	@echo Uninstalling whois client
	-rm -f $(PREFIX)/usr/bin/whois_client.py

uninstall-client-genzone:
	@echo Uninstalling genzone client
	-rm -f $(PREFIX)/usr/bin/genzone_client.py
	-rm -f $(PREFIX)/usr/bin/genzones.sh
	-@cmp ../clients/genzone/skels/genzones $(PREFIX)/etc/default/genzones 2>&1 1>&/dev/null;\
	  if [ $$? -eq 0 ]; then \
		rm -f $(PREFIX)/etc/default/genzones;\
		echo Configuration file $(PREFIX)/etc/default/genzones deleted;\
	  else \
		echo Delete config file $(PREFIX)/etc/default/genzones if ;\
		echo you are not going to reinstall genzone client.;\
	  fi
	-@cmp ../clients/genzone/skels/zone-prefix $(PREFIX)/etc/bind/zone-prefix 2>&1 1>&/dev/null;\
	  if [ $$? -eq 0 ]; then \
		rm -f $(PREFIX)/etc/bind/zone-prefix;\
		echo Configuration file $(PREFIX)/etc/bind/zone-prefix deleted;\
	  else \
		echo Delete config file $(PREFIX)/etc/bind/zone-prefix if ;\
		echo you are not going to reinstall genzone client.;\
	  fi
	-@cmp ../clients/genzone/skels/zone-postfix $(PREFIX)/etc/bind/zone-postfix 2>&1 1>&/dev/null;\
	  if [ $$? -eq 0 ]; then \
		rm -f $(PREFIX)/etc/bind/zone-postfix;\
		echo Configuration file $(PREFIX)/etc/bind/zone-postfix deleted;\
	  else \
		echo Delete config file $(PREFIX)/etc/bind/zone-postfix if ;\
		echo you are not going to reinstall genzone client.;\
	  fi

clean:
	-rm -fr ccReg
	-rm -fr ccReg__POA
	-rm -f *.pyc
	-rm -f ${GENZONE}_idl.py ${WHOIS}_idl.py

