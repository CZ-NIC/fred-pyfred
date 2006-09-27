IDL     = "../../cr/idl/Whois.idl"

.PHONY: idl install clean

idl:
	omniidl -bpython -Wbinline ${IDL}

clean:
	rm -fr ccReg
	rm -fr ccReg__POA
	rm -f *.pyc
	rm -f Whois_idl.py
