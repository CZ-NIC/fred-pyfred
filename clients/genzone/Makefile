IDL     = "../../cr/idl/ZoneGenerator.idl"
DESTDIR = "/usr/local/ccRegUtils" 
 
.PHONY: idl install clean 
 
idl: 
	omniidl -bpython -Wbinline ${IDL} 
 
install: 
	mkdir -p $(DESTDIR) 
	cp -fr ccReg ccReg__POA ${DESTDIR} 
	cp -f ZoneGenerator_idl.py ${DESTDIR} 
	cp -f genzone_client.py ${DESTDIR} 
	cp -f genzones.sh ${DESTDIR} 
 
clean: 
	rm -fr ccReg 
	rm -fr ccReg__POA 
	rm -f *.pyc 
	rm -f ZoneGenerator_idl.py 

