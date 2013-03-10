all:
	hbmk2 -q0 -w3 -ge1 -mt -shared -gtcgi hisbay.prg hbtip.hbc xhb.hbc -ohisbay


clean:
	rm hisbay

install: all
