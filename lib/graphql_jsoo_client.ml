(* module type Connection_pub = sig
 * type t
 * (\** Type of the connection  *\)
 * 
 * val trace_console : string -> unit
 * (\** send traces to console *\)
 * 
 * val connect :
 *   ?trace:(string -> unit) ->
 *   ?host:string option ->
 *   ?port:int option -> string -> t Lwt.t
 * (\** [connect ~trace ~host ~port path] creates a WebSocket connection
 *    to the given host, port and path. If no host or port is given it
 *    will use the one the page (if any) is served from. Trace can be
 *    used to trace events. Default is no trace.
 * 
 *     Returns a connection object *\)
 * 
 * val disconnect : t  -> 
 *   unit
 * (\** [disconnect con] disconnect the websocket assosiated with the
 *    connection *\)
 * 
 * end *)

(* module Connection : Connection_pub = Connection  *)
module QuerySig = QuerySig
module Client = Client

