APPNAME=ld43

web:
	nim js -o:${APPNAME}.js src/main.nim

webr:
	nim js -d:release -o:${APPNAME}.js src/main.nim

rund:
	nim c -d:gif -r -o:${APPNAME}d src/main.nim

run:
	nim c -d:gif -r -d:release -o:${APPNAME} src/main.nim

runp:
	nim c --profiler:on --stackTrace:on -r -d:release -o:${APPNAME}p src/main.nim
