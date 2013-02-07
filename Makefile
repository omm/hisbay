all:
	hbmk2 -q0 -w3 -ge1 -mt -shared -gtcgi hisbay.prg hbtip.hbc xhb.hbc -ohisbay.exe


clean:
	rm hisbay.exe

install: all
