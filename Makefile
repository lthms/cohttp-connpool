PROJECT=cohttp-connpool-eio
OCAML_VERSION=5.3.0
DUNE_VERSION=3.19.0

.PHONY: build
build: ${PROJECT}.opam
	dune build -p ${PROJECT}

.PHONY: opam-setup-local-switch
opam-setup-local-switch:
	@if ! opam switch list --short | grep -q "^$(shell pwd)$$" > /dev/null; then \
		opam switch create .  --no-install --packages ocaml.${OCAML_VERSION},dune.${DUNE_VERSION} --deps-only -y; \
	fi

%.opam: opam-setup-local-switch dune-project
	dune build $@

.PHONY: build-deps
build-deps: ${PROJECT}.opam
	opam pin ${PROJECT} . --no-action -y
	opam install ${PROJECT} --deps-only -y

.PHONY: build-dev-deps
build-dev-deps: ${PROJECT}-dev.opam build-deps
	opam pin ${PROJECT}-dev . -y
	opam install ${PROJECT}-dev --deps-only -y
