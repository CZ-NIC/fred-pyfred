TOP_REPOS = ../../../..
IDL       = ${TOP_REPOS}/idl/trunk/ZoneGenerator.idl
DESTDIR   = /usr/local/ccRegUtils
 
.PHONY: idl install clean 
 
idl: 
	omniidl -bpython -Wbinline ${IDL} 
 
install: 
	mkdir -p $(DESTDIR) 
	cp -fr ccReg ccReg__POA ${DESTDIR} 
	cp -f ZoneGenerator_idl.py ${DESTDIR} 
	cp -f genzone_client.py ${DESTDIR} 
	cp -f genzones.sh ${DESTDIR} 
 
uninstall:
	- rm -rf $(DESTDIR)

clean: 
	rm -fr ccReg 
	rm -fr ccReg__POA 
	rm -f *.pyc 
	rm -f ZoneGenerator_idl.py 

