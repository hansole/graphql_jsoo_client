A library for making WebSocket connections for use with with
[GraphQL](https://graphql.org/).

This is the client side implementation of the [GraphQL over WebSocket
Protocol](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md).
It is mainly intended for use with
[Dream](https://aantron.github.io/dream/), which implements the server
side. This library supports writing client code in Ocaml, that will
run in the browser.

## Building and install
It can be installed from source
```shell
graphql_jsoo_client$ dune build
graphql_jsoo_client$ dune install
```

If you makes changes to the schema of the server, you need to first
build and run the server.

```shell
graphql_jsoo_client$ dune build example/server
graphql_jsoo_client$ ./_build/default/example/server/server.exe
```
The export the scheme that will be used by the [ocaml_ppx](https://github.com/teamwalnut/graphql-ppx) pre-processor.

```code
graphql_jsoo_client$ npx get-graphql-schema http://127.0.0.1:8080/graphql -j > graphql_schema.json
```

Then you can build the frontend against the servers schema.

```shell
graphql_jsoo_client$ dune build example/frontend
```

```shell
graphql_jsoo_client$ dune build
```
It can be installed using `opam`
```shell
graphql_jsoo_client$ dune build graphql_jsoo_client.opam
graphql_jsoo_client$ opam install .
```
(I will try to add it to the opam repository at some later time)

<!-- It can be installed using `opam` -->
<!-- ```shell -->
<!-- $ opam install graphql_jsoo_client -->
<!-- ```  -->

## Usage
The `example` directory has a server and a client that uses the
library. It show how to do simple queries with GraphQL over
WebSockets. In addition it has an example of subscriptions to a
counter that counts until a limit.

There is also an example of a ping pong between the server and client
where the server sends updates when a subscribed counter is updated.
The client modifies this value and send it to the server as a
mutation. In which case the server sends the modification as an update
to the subscribed client, and so on.

## Issues
Dream installed using the current version in opam, depends on a
library that has a bug hat cases server to use 100% CPU when using
WebSocket. The issue and a workaround for this can be found
[here](https://github.com/aantron/dream/issues/230).

There also seems to be a issue with Dream with WebSockets using [large
payloads](https://github.com/aantron/dream/issues/214).


And there are probably issues with the library, so feel free to report
any findings.

## References
The work has been inspired by [Full-Stack WebDev in OCaml
Intro](https://ceramichacker.com/blog/26-1x-full-stack-webdev-in-ocaml-intro).
