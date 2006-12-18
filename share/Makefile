PREFIX       =
TOP_REPOS    = ../../..
IDLDIR       = ${TOP_REPOS}/idl/branches/devel
INSTALL      = ./install-sh
GENZONE      = ZoneGenerator
WHOIS        = Whois
MAILER       = Mailer
FILEMANAGER  = FileManager
TECHCHECK    = TechCheck

.PHONY: all build clean

all: build
	-@echo
	-@echo Type \"make install-server\" in order to install pyfred server
	-@echo and \"make install-clients\" to install clients. Type \"make
	-@echo install\" to install both. If you decide to install only server
	-@echo or only clients do not forget to type \"make install-idl\".
	-@echo

build: $(IDLDIR)/$(GENZONE).idl $(IDLDIR)/$(WHOIS).idl $(IDLDIR)/$(MAILER).idl
	omniidl -bpython -Wbinline ${IDLDIR}/${GENZONE}.idl ${IDLDIR}/${WHOIS}.idl ${IDLDIR}/${MAILER}.idl ${IDLDIR}/${FILEMANAGER}.idl ${IDLDIR}/${TECHCHECK}.idl

install: install-idl install-server install-clients

install-idl: build
	@echo Installing shared IDL
	$(INSTALL) -d $(PREFIX)/usr/lib/pyfred/share
	cp -r ccReg                  $(PREFIX)/usr/lib/pyfred/share
	cp -r ccReg__POA             $(PREFIX)/usr/lib/pyfred/share
	$(INSTALL) $(GENZONE)_idl.py $(PREFIX)/usr/lib/pyfred/share
	$(INSTALL) $(WHOIS)_idl.py   $(PREFIX)/usr/lib/pyfred/share
	$(INSTALL) $(MAILER)_idl.py  $(PREFIX)/usr/lib/pyfred/share
	$(INSTALL) $(FILEMANAGER)_idl.py  $(PREFIX)/usr/lib/pyfred/share
	$(INSTALL) $(TECHCHECK)_idl.py  $(PREFIX)/usr/lib/pyfred/share

install-server: \
		../server/pyfred.py \
		../server/pyfred_util.py \
		../server/genzone.py \
		../server/whois.py \
		../server/mailer.py \
		../server/filemanager.py \
		../server/techcheck.py \
		../server/pyfred_modules.conf \
		../server/pyfred.conf
	@echo Installing pyfred server
	$(INSTALL) -d $(PREFIX)/usr/bin
	$(INSTALL) -d $(PREFIX)/usr/lib/pyfred/server
	$(INSTALL) -d $(PREFIX)/etc
	$(INSTALL) ../server/pyfred.py      $(PREFIX)/usr/bin
	$(INSTALL) ../server/pyfred_util.py $(PREFIX)/usr/lib/pyfred/server
	$(INSTALL) ../server/genzone.py     $(PREFIX)/usr/lib/pyfred/server
	$(INSTALL) ../server/whois.py       $(PREFIX)/usr/lib/pyfred/server
	$(INSTALL) ../server/mailer.py      $(PREFIX)/usr/lib/pyfred/server
	$(INSTALL) ../server/filemanager.py $(PREFIX)/usr/lib/pyfred/server
	$(INSTALL) ../server/techcheck.py   $(PREFIX)/usr/lib/pyfred/server
	@cmp ../server/pyfred_modules.conf $(PREFIX)/etc/pyfred_modules.conf 2>&1 1>&/dev/null;\
	  if [ $$? -ne 1 ]; then \
	    $(INSTALL) ../server/pyfred_modules.conf $(PREFIX)/etc;\
	    echo Config file $(PREFIX)/etc/pyfred_modules.conf installed;\
	  else \
		echo Config file $(PREFIX)/etc/pyfred_modules.conf not;\
		echo overwritten because of detected changes.;\
	  fi
	@cmp ../server/pyfred.conf $(PREFIX)/etc/pyfred.conf 2>&1 1>&/dev/null;\
	  if [ $$? -ne 1 ]; then \
	    $(INSTALL) ../server/pyfred.conf $(PREFIX)/etc;\
	    echo Config file $(PREFIX)/etc/pyfred.conf installed;\
	  else \
		echo Config file $(PREFIX)/etc/pyfred.conf not;\
		echo overwritten because of detected changes.;\
	  fi

install-clients: install-client-whois install-client-genzone install-client-mailer install-client-filemanager install-client-techcheck

install-client-whois: ../clients/whois/whois_client.py
	@echo Installing whois client
	$(INSTALL) -d $(PREFIX)/usr/bin;
	$(INSTALL) ../clients/whois/whois_client.py $(PREFIX)/usr/bin

install-client-mailer: ../clients/mailer/mailer_client.py
	@echo Installing mailer client
	$(INSTALL) -d $(PREFIX)/usr/bin;
	$(INSTALL) ../clients/mailer/mailer_client.py $(PREFIX)/usr/bin

install-client-filemanager: ../clients/filemanager/filemanager_client.py
	@echo Installing filemanager client
	$(INSTALL) -d $(PREFIX)/usr/bin;
	$(INSTALL) ../clients/filemanager/filemanager_client.py $(PREFIX)/usr/bin

install-client-techcheck: ../clients/techcheck/techcheck_client.py
	@echo Installing techcheck client
	$(INSTALL) -d $(PREFIX)/usr/bin;
	$(INSTALL) ../clients/techcheck/techcheck_client.py $(PREFIX)/usr/bin

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
	-rmdir  $(PREFIX)/usr/lib/pyfred 2>/dev/null

uninstall-idl:
	@echo Uninstalling shared IDL
	-rm -f  $(PREFIX)/usr/lib/pyfred/share/$(TECHCHECK)_idl.py
	-rm -f  $(PREFIX)/usr/lib/pyfred/share/$(FILEMANAGER)_idl.py
	-rm -f  $(PREFIX)/usr/lib/pyfred/share/$(MAILER)_idl.py
	-rm -f  $(PREFIX)/usr/lib/pyfred/share/$(WHOIS)_idl.py
	-rm -f  $(PREFIX)/usr/lib/pyfred/share/$(GENZONE)_idl.py
	-rm -rf $(PREFIX)/usr/lib/pyfred/share/ccReg
	-rm -rf $(PREFIX)/usr/lib/pyfred/share/ccReg__POA
	-rmdir  $(PREFIX)/usr/lib/pyfred/share 2>/dev/null

uninstall-server:
	@echo Uninstalling pyfred server
	-rm -f $(PREFIX)/usr/bin/pyfred.py
	-rm -f $(PREFIX)/usr/lib/pyfred/server/pyfred_util.py
	-rm -f $(PREFIX)/usr/lib/pyfred/server/genzone.py
	-rm -f $(PREFIX)/usr/lib/pyfred/server/whois.py
	-rm -f $(PREFIX)/usr/lib/pyfred/server/mailer.py
	-rm -f $(PREFIX)/usr/lib/pyfred/server/techcheck.py
	@echo File manager's repository must be uninstalled manualy.
	-@cmp ../server/pyfred_modules.conf $(PREFIX)/etc/pyfred_modules.conf 2>&1 1>&/dev/null;\
	  if [ $$? -eq 0 ]; then \
		rm -f $(PREFIX)/etc/pyfred_modules.conf;\
		echo Config file $(PREFIX)/etc/pyfred_modules.conf deleted;\
	  else \
		echo Delete config file $(PREFIX)/etc/pyfred_modules.conf if ;\
		echo you are not going to reinstall pyfred server.;\
	  fi
	-@cmp ../server/pyfred.conf $(PREFIX)/etc/pyfred.conf 2>&1 1>&/dev/null;\
	  if [ $$? -eq 0 ]; then \
		rm -f $(PREFIX)/etc/pyfred.conf;\
		echo Config file $(PREFIX)/etc/pyfred.conf deleted;\
	  else \
		echo Delete config file $(PREFIX)/etc/pyfred.conf if ;\
		echo you are not going to reinstall pyfred server.;\
	  fi
	-rmdir $(PREFIX)/usr/lib/pyfred/server 2>/dev/null

uninstall-clients: uninstall-client-whois uninstall-client-genzone uninstall-client-mailer uninstall-client-filemanager uninstall-client-techcheck

uninstall-client-whois:
	@echo Uninstalling whois client
	-rm -f $(PREFIX)/usr/bin/whois_client.py

uninstall-client-mailer:
	@echo Uninstalling mailer client
	-rm -f $(PREFIX)/usr/bin/mailer_client.py

uninstall-client-filemanager:
	@echo Uninstalling filemanager client
	-rm -f $(PREFIX)/usr/bin/filemanager_client.py

uninstall-client-techcheck:
	@echo Uninstalling techcheck client
	-rm -f $(PREFIX)/usr/bin/techcheck_client.py

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
	-rm -f ${GENZONE}_idl.py ${WHOIS}_idl.py ${MAILER}_idl.py ${FILEMANAGER}_idl.py ${TECHCHECK}_idl.py

