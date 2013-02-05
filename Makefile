all:
	hbmk2 -q0 -w3 -ge1 -mt -shared -gtcgi hisbay.prg -lhbtip -lhblog -lhbxml -lhbpgsql -lhbmzip -lhbct -lhbvpdf -lhbgd -ohisbay.exe


clean:
	rm hisbay.exe

install: all
