IDLDIR      = idl
GENZONE      = ZoneGenerator
WHOIS        = Whois
INSTALL      = ./install-sh
DESTDIR      = /usr/local/dns

.PHONY: build clean install

build:
	omniidl -bpython -Wbinline ${IDLDIR}/${GENZONE}.idl ${IDLDIR}/${WHOIS}.idl

install:
	${INSTALL} -d ${DESTDIR}
	cp -fr ccReg ccReg__POA ${DESTDIR}
	${INSTALL} -m 0644 ${GENZONE}_idl.py ${DESTDIR}
	${INSTALL} -m 0644 ${WHOIS}_idl.py ${DESTDIR}
	${INSTALL} -m 0644 genzone.py ${DESTDIR}
	${INSTALL} -m 0644 whois.py ${DESTDIR}
	${INSTALL} -m 0644 ccreg_util.py ${DESTDIR}
	${INSTALL} -m 0755 pyccReg.py ${DESTDIR}
	${INSTALL} -m 0644 modules.conf ${DESTDIR}
	${INSTALL} -m 0755 pyccReg.sh ${DESTDIR}
	${INSTALL} -m 0755 omniNames.sh ${DESTDIR}

uninstall:
	rm -rf ${DESTDIR}

clean:
	rm -fr ccReg
	rm -fr ccReg__POA
	rm -f *.pyc
	rm -f ${GENZONE}_idl.py ${WHOIS}_idl.py
	rm -f omniNames.log
	#rm -f omninames-*
