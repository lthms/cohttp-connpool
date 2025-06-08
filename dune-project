(lang dune 3.14)

(generate_opam_files true)

(name cohttp-connpool)

(maintainers "Thomas Letan <lthms@soap.coffee>")
(authors "Thomas Letan <lthms@soap.coffee>")
(source (github lthms/cohttp-connpool-eio))

(package
 (name cohttp-connpool-eio)
 (version "0.1.0")
 (synopsis "Pool of persistent HTTP connections")
 (description
"This library provides a connection pool for cohttp-eio, enabling efficient
reuse of HTTP connections within an Eio application. This helps reduce
latency and resource overhead by minimizing the need to establish new TCP
connections for each request.")
 (homepage "https://github.com/lthms/cohttp-connpool-eio")
 (bug_reports "https://github.com/lthms/cohttp-connpool-eio#issues")
 (documentation "https://github.com/lthms/cohttp-connpool-eio#readme")
 (license "mpl-2.0")
 (depends dune cohttp-eio))

(package
 (allow_empty)
 (name cohttp-connpool-dev)
 (maintainers "Thomas Letan <lthms@soap.coffee>")
 (synopsis
  "Virtual package gathering developers dependencies for hacking this project")
 (depends
  eio_main ; necessary to run examples
  dune-release
  ocaml-lsp-server
  odoc
  tls-eio
  ca-certs
  (ocamlformat
   (= 0.27.0))))
