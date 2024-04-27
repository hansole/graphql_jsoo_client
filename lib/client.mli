val connect :                   
  ?trace:(string -> unit) ->
  ?protocol:string  ->
  ?host:string option ->
  ?port:int option -> string -> Connection.t Lwt.t
(** [connect ~trace ~host ~port path] creates a WebSocket connection
   to the given host, port and path. If no host or port is given it
   will use the one the page (if any) is served from. Trace can be
   used to trace events. Default is no trace.

   Protocol is "ws" or "wss" for secure connections.

    Returns a connection object *)


val disconnect :  Connection.t -> unit
(** [disconnect con] disconnect the websocket assosiated with the
   connection *)

val debug_list_handlers :
  Connection.t -> (string * float * string) list
(** [debug_list_handlers con ] returns a list of handlers associated
   with connection. The list has typples of (id, time added, operation
   type)*)

val trace_console : string -> unit
(** send traces to console *)

val string_of_state : Connection.t -> string
(** [string_of_state con] returns a string for the connection state *)

module Make :
  functor (Q : QuerySig.Query) ->
    sig
      type response =
          Success of Q.t
        | Unauthorized
        | Forbidden
        | NotFound
        | TooManyRequests
        | OtherError of string
      (* val query_to_json : string -> Q.t_variables -> Yojson.Safe.t
       * val subscribe_message : string -> Yojson.Basic.t -> string
       * val query_message : string -> Yojson.Basic.t -> string
       * val complete_message : string -> string
       * val parse : Yojson.Basic.t -> Q.t *)
      val subscribe :
        Connection.t ->
        Q.t_variables -> (Q.t -> unit) -> string Lwt.t
      (** [subscribe con arguments handler] Make a subscrption using
         WebSocket connection

          Returns the ID of the subscription *)

      val unsubscribe :
        Connection.t -> string -> unit Lwt.t
      (** [query con id ] Unsubscribe the given id *)
          

      val query :
        Connection.t -> Q.t_variables -> response Lwt.t
        (** [query con arguments ] Mkae a query

          Returns result of query *)

      val ping : Connection.t -> Yojson.Basic.t -> unit Lwt.t
      (** [ping con payload] Send a ping message on the connection

          NOTE: Not tested as GraphQL with Dream don't seem to support
         message type *) 

      val pong : Connection.t -> Yojson.Basic.t -> unit Lwt.t
      (** [pong con payload] Send a pong message on the connection

          NOTE: Not tested as GraphQL with Dream don't seem to support
         message type *) 

    end

