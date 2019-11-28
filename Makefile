#
# $Id: Makefile 16196 2009-12-15 20:36:21Z thierry $
# $URL: https://svn.planet-lab.org/svn/vsys/branches/0.9/Makefile $
#

# OCAML_OLD is set to non-empty if str.cmxa needs to be passed twice to the loader
OCAML_RELEASE := $(shell ocaml -version)
OCAML_OLD := $(strip $(findstring version 3.09,$(OCAML_RELEASE)) $(findstring version 3.10,$(OCAML_RELEASE)))

all: vsys docs

include .dep

.SUFFIXES: .ml .cmo
.SUFFIXES: .mli .cmi
.SUFFIXES: .ml .cmx
.SUFFIXES: .mll .ml
.SUFFIXES: .mly .ml

.ml.cmo:
	ocamlc -g -c $(INCLUDEDIR) $<

.mli.cmi:
	ocamlopt -c $<

.ml.cmx: 
	ocamlopt $(CFLAGS) -c $(INCLUDEDIR) $<

.mly.ml: 
	ocamlyacc $< 

.mll.ml:
	ocamllex $< 

docs: *.ml
	ocamldoc -d . -html -o docs *.ml
	mkdir -p docs;mv *.html *.css docs

ocaml_inotify-0.4/inotify.cmxa:
	$(MAKE) -C ocaml_inotify-0.4 && cp -f ocaml_inotify-0.4/inotify_stubs.o ./

splice_stub.o: splice_stub.c
	gcc -c -I /usr/lib/ocaml -I /usr/lib64/ocaml splice_stub.c -o splice_stub.o -fPIC

vsys: ocaml_inotify-0.4/inotify.cmxa globals.cmx fdwatcher.cmx conffile.cmx splice_stub.o splice.cmx dirwatcher.cmx fifowatcher.cmx frontend.cmx unixsocketwatcher.cmx backend.cmx main.cmx 
ifneq "$(OCAML_OLD)" ""
	ocamlopt -I ocaml_inotify-0.4 str.cmxa unix.cmxa inotify.cmxa globals.cmx fdwatcher.cmx dirwatcher.cmx splice.cmx splice_stub.o directfifowatcher.cmx unixsocketwatcher.cmx  frontend.cmx backend.cmx str.cmxa conffile.cmx main.cmx -o vsys
else
	ocamlopt -I ocaml_inotify-0.4 str.cmxa unix.cmxa inotify.cmxa globals.cmx fdwatcher.cmx dirwatcher.cmx splice.cmx splice_stub.o directfifowatcher.cmx unixsocketwatcher.cmx  frontend.cmx backend.cmx conffile.cmx main.cmx -o vsys
endif

vsys.b: ocaml_inotify-0.4/inotify.cma inotify.cmi globals.ml fdwatcher.ml dirwatcher.ml directfifowatcher.ml frontend.ml backend.ml main.ml
	ocamlc -g str.cma unix.cma ocaml_inotify-0.4/inotify.cma globals.cmo fdwatcher.cmo dirwatcher.cmo directfifowatcher.cmo frontend.cmo backend.cmo str.cma conffile.cmo main.cmo -o vsys.b

install: vsys
	cp vsys $(INSTALL_DIR)/usr/bin
	cp vsys-initscript $(INSTALL_DIR)/etc/init.d/vsys 

.dep:
	ocamldep *.ml > .dep

clean:
	$(MAKE) -C ocaml_inotify-0.4 clean
	rm -f *.cmi *.cmx sys usys *.o vsys vsys.b *.html *.css 
