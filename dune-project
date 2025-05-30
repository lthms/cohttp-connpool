(lang dune 3.19)

(generate_opam_files true)

(name cohttp-connpool-eio)

(package
 (name cohttp-connpool-eio)
 (version "0.1.0")
 (synopsis "Pool of persistent HTTP connections")
 (description "A short description of the cohttp-connpool-eio package.")
 (maintainers "Thomas Letan <lthms@soap.coffee>")
 (homepage "https://github.com/lthms/cohttp-connpool-eio")
 (documentation "https://github.com/lthms/cohttp-connpool-eio#readme")
 (depends dune cohttp-eio logs))

(package
 (allow_empty)
 (name cohttp-connpool-eio-dev)
 (maintainers "Thomas Letan <lthms@soap.coffee>")
 (synopsis
  "Virtual package gathering developers dependencies for hacking this project")
 (depends
  eio_main ; necessary to run examples
  dune-release
  ocaml-lsp-server
  odoc
  (ocamlformat
   (= 0.27.0))))
