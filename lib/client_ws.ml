open! Js_of_ocaml
open! Connection


(* let yojson_of_string = Ppx_yojson_conv_lib__Yojson_conv.yojson_of_string *)

module ForQuery (Q : QuerySig.Query) = struct

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


  let subscribe (con : Connection.ws_connection) vars handler =
    let yojson = query_to_json Q.query vars in
    (* let qjson = Yojson.Safe.to_string yojson in *)
    let uuid = Uuidm.(v `V4) |> Uuidm.to_string in
    let json = subscribe_message uuid (Yojson.Safe.to_basic yojson) in
    (* Printf.printf "HANS: body '%s'\n%!" json; *)
    let handler_wrapper body_json =
      let body_unsafe = Q.unsafe_fromJson body_json in
      let body = Q.parse body_unsafe in
      handler body
    in
    Hashtbl.add con.handlers uuid (Subscribe handler_wrapper);
    con.ws##send (Js.string (json));
    Lwt.return uuid

  let query (con : Connection.ws_connection) vars =
    let yojson = query_to_json Q.query vars in
    (* let qjson = Yojson.Safe.to_string yojson in *)
    let uuid = Uuidm.(v `V4) |> Uuidm.to_string in
    let json = query_message uuid (Yojson.Safe.to_basic yojson) in
    (* Printf.printf "HANS: body '%s'\n%!" json; *)
    let ww, s = Lwt.wait () in
    let handler_fun m =
      match m with 
      | Connection.Success body_json ->
        (* let body_unsafe = Q.unsafe_fromJson body_json in
         * let body = Q.parse body_unsafe in *)
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
    Hashtbl.add con.handlers uuid (Query (handler_fun, None));
    con.ws##send (Js.string (json));
    ww

  let unsubscribe (con : Connection.ws_connection) uuid =
    let json = complete_message uuid in
    Hashtbl.remove con.handlers uuid;
    con.ws##send (Js.string (json));
    Lwt.return_unit

end
