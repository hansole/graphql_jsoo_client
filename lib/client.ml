open! Js_of_ocaml
open! Connection


(* type connection = Connection.t *)
(* let yojson_of_string = Ppx_yojson_conv_lib__Yojson_conv.yojson_of_string *)

(* Export some cunctions form Connection module *)
let connect = Connection.connect
let disconnect = Connection.disconnect
let debug_list_handlers = Connection.debug_list_handlers
let trace_console = Connection.trace_console
let string_of_state = Connection.string_of_state

module Make (Q : QuerySig.Query) = struct

  type response =
    | Success of Q.t
    | Unauthorized
    | Forbidden
    | NotFound
    | TooManyRequests
    | OtherError of string

  let query_to_json (q: string) vars =
    let yojson = `Assoc [
        "query",
        `String q;
        "variables",
        vars |> Q.serializeVariables |> Q.variablesToJson;
      ] |> Yojson.Basic.to_string
                 |> Yojson.Safe.from_string
    in
    yojson

  let subscribe_message id query (* variables *) =
    `Assoc [
      "type", `String "subscribe";
      "id", `String id;
      "payload",
      query;
      (* "variables", `String variables; *)
    ]
    |> Yojson.Basic.to_string

  let query_message id query (* variables *) =
    `Assoc [
      "type", `String "subscribe";
      "id", `String id;
      "payload",
      query;
    ]
    |> Yojson.Basic.to_string

  let complete_message id =
    `Assoc [
      "type", `String "complete";
      "id", `String id;
    ]
    |> Yojson.Basic.to_string


  let parse body_json =
    let body_unsafe = Q.unsafe_fromJson body_json in
    let body = Q.parse body_unsafe in
    body


  let subscribe (con : Connection.t) vars handler =
    let yojson = query_to_json Q.query vars in
    let uuid = Uuidm.(v `V4) |> Uuidm.to_string in
    let json = subscribe_message uuid (Yojson.Safe.to_basic yojson) in
    let handler_wrapper body_json =
      let body_unsafe = Q.unsafe_fromJson body_json in
      let body = Q.parse body_unsafe in
      handler body
    in
    Connection.add_handler con uuid (Subscribe handler_wrapper);
    Connection.send con json;
    Lwt.return uuid

  let query (con : Connection.t) vars =
    let yojson = query_to_json Q.query vars in
    let uuid = Uuidm.(v `V4) |> Uuidm.to_string in
    let json = query_message uuid (Yojson.Safe.to_basic yojson) in
    let ww, s = Lwt.wait () in
    let handler_fun m =
      match m with 
      | Connection.Success body_json ->
        let body = parse body_json in
        Lwt.wakeup_later s (Success body)
      | Connection.Unauthorized ->
        Lwt.wakeup_later s (Unauthorized)
      | Connection.Forbidden ->
        Lwt.wakeup_later s (Forbidden)
      | Connection.NotFound ->
        Lwt.wakeup_later s (NotFound)
      | Connection.TooManyRequests ->
        Lwt.wakeup_later s (TooManyRequests)
      | Connection.OtherError e ->
        Lwt.wakeup_later s (OtherError e)
    in
    Connection.add_handler con uuid (Query (handler_fun, None));
    Connection.send con json;
    ww

  let unsubscribe (con : Connection.t) uuid =
    let json = complete_message uuid in
    Connection.remove_handler con uuid;
    Connection.send con json;
    Lwt.return_unit

  let ping con payload =
    let msg = Connection.ping_message payload in
    Connection.send con msg;
    Lwt.return_unit

  let pong con payload =
    let msg = Connection.pong_message payload in
    Connection.send con msg;
    Lwt.return_unit


end
