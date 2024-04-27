(**
   WebSocket connections 
*)

type t
(** Type of the connection  *)

type response =
    Success of Yojson.Basic.t
  | Unauthorized
  | Forbidden
  | NotFound
  | TooManyRequests
  | OtherError of string

type operation =
    Query of ((response -> unit) * Yojson.Basic.t option)
  | Subscribe of (Yojson.Basic.t -> unit)
  | Mutation of string

type state =
  | Connecting
  | Connected
  | Disconnecting
  | Disconnected

val string_of_state : t -> string
(** [string_of_state con] returns a string for the connection state *)

val trace_console : string -> unit
(** send traces to console *)

val ping_message : Yojson.Basic.t -> string
(** [ping_message payload]

    Returns a string representing a ping message with the given
   payload *)

val pong_message : Yojson.Basic.t -> string
(** [pong_message payload]

    Returns a string representing a pong message with the given
   payload *)

val connect :
  ?trace:(string -> unit) ->
  ?protocol:string  ->
  ?host:string option ->
  ?port:int option -> string -> t Lwt.t
(** [connect ~trace ~protocol ~host ~port path] creates a WebSocket connection
   to the given host, port and path. If no host or port is given it
   will use the one the page (if any) is served from. Trace can be
   used to trace events. Default is no trace.

   Protocol is "ws" or "wss" for secure connections.

    Returns a connection object *)

val disconnect : t  -> 
  unit
(** [disconnect con] disconnect the websocket assosiated with the
   connection *)


val send : t -> string -> unit
(** [send con msg] sends a serialized graphql JSON string on the
   WebSocket connection *)

val add_handler : t -> string -> operation -> unit
(** [add_handler con id operation] add a handler to the connection.
   Handlers within a connection must have uniq IDs. *)

val remove_handler : t -> string -> unit
(** [remove_handler con id ] removes the handler with the given ID *)

val debug_list_handlers : t -> (string * float * string) list
(** [debug_list_handlers con ] returns a list of handlers associated
   with connection. The list has typples of (id, time added, operation
   type)*)
