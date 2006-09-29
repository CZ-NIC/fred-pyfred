TOP_REPOS = ../../../..
IDL       = ${TOP_REPOS}/idl/trunk/Whois.idl

.PHONY: idl clean

idl:
	omniidl -bpython -Wbinline ${IDL}

clean:
	rm -fr ccReg
	rm -fr ccReg__POA
	rm -f *.pyc
	rm -f Whois_idl.py
