CC = gcc
CFLAGS = -Wall -O2 -fPIC
OCAMLC = ocamlc
OCAMLOPT = ocamlopt

OCAMLOPTFLAGS =

OCAML_TEST_INC = -I `ocamlfind query oUnit`
OCAML_TEST_LIB = `ocamlfind query oUnit`/oUnit.cmxa

LIBS = inotify.cmi inotify.cmxa inotify.cma
PROGRAMS = test.inotify

all: $(LIBS) $(PROGRAMS)

bins: $(PROGRAMS)

libs: $(LIBS)

inotify.cma: inotify_stubs.o inotify.cmo
	$(OCAMLC) -a -o $@ -custom $+

inotify.cmxa: inotify_stubs.o inotify.cmx
	$(OCAMLOPT) $(OCAMLOPTFLAGS) -a -o $@ $+

%.cmo: %.ml
	$(OCAMLC) -c -o $@ $<

%.cmi: %.mli
	$(OCAMLC) -c -o $@ $<

%.cmx: %.ml
	$(OCAMLOPT) $(OCAMLOPTFLAGS) -c -o $@ $<

%.o: %.c
	$(CC) -I /usr/lib/ocaml -I /usr/lib64/ocaml $(CFLAGS) -c -o $@ $<

test.inotify: inotify.cmxa test.inotify.ml
	$(OCAMLOPT) -o $@ unix.cmxa $+

clean:
	rm -f *.o *.a *.cmo *.cmi *.cma *.cmx *.cmxa $(LIBS) $(PROGRAMS)
