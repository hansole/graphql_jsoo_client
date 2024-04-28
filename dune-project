(lang dune 3.13)

(name graphql_jsoo_client)

(generate_opam_files true)

(source
 (github hansole/graphql_jsoo_client))

(authors "Hans Ole Rafaelsen")

(maintainers "Hans Ole Rafaelsen")

(license MIT)

;(documentation https://url/to/documentation)

(package
 (name graphql_jsoo_client)
 (synopsis "GrpahQL over WebSocket client")
 (description "A GraphQl client that can be compiled using jsoo to access GraphQl servers using websocket. It was created with the main purpose of using it in combination with the Dream web-framework.")
 (depends ocaml dune
  dream 
  graphql_ppx
  cohttp-lwt-jsoo
  js_of_ocaml-ppx
  ppx_yojson_conv
  uuidm
  ppx_typed_fields
 )
 (tags
  ("graphql" "jsoo" "websockets"))


)

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
