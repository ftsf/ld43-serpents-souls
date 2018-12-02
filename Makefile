APPNAME=ld43
NICO="-p:../nico"

web:
	nim js $(NICO) -d:debug -o:$(APPNAME).js src/main.nim

webr:
	nim js $(NICO) -d:release -o:${APPNAME}.js src/main.nim

rund:
	nim c $(NICO) -d:gif -r -d:debug -o:${APPNAME}d src/main.nim

run:
	nim c $(NICO) -d:gif -r -d:release -o:${APPNAME} src/main.nim
