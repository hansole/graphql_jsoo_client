open Lwt.Infix

let yojson_of_string = Ppx_yojson_conv_lib__Yojson_conv.yojson_of_string

module ForQuery (Q : QuerySig.Query) = struct
  (* module SerializableQ = Queries.SerializableQuery(Q) *)

  type response = 
    | Success of Q.t
    | Unauthorized
    | Forbidden
    | NotFound
    | TooManyRequests
    | OtherError of string

  let url = Uri.of_string "/graphql"

  let create_body q vars =
    let yojson = `Assoc [
        "query",
        `String q;
        "variables",
        vars |> Q.serializeVariables |> Q.variablesToJson;
      ] |> Yojson.Basic.to_string
                 |> Yojson.Safe.from_string
    in
    let json = Yojson.Safe.to_string yojson in
    Cohttp_lwt.Body.of_string json

  let query ?(url = url) vars =
    Cohttp_lwt_jsoo.Client.post
      ~headers:(Cohttp.Header.init_with "Content-Type" "application/json")
      ~body:(create_body Q.query vars ) url
    (* ~body:(create_body Q.query vars) url *)
    >>= fun (resp, raw_body) ->
    let body_str_lwt = Cohttp_lwt.Body.to_string raw_body in
    body_str_lwt >|= fun body_str ->
    match resp.status with
    | #Cohttp.Code.success_status ->
      let full_body_json = Yojson.Basic.from_string body_str in
      let body_json = Yojson.Basic.Util.member "data" full_body_json in
      let body_unsafe = Q.unsafe_fromJson body_json in
      let body = Q.parse body_unsafe in
      Success body
    | `Unauthorized -> Unauthorized
    | `Forbidden -> Forbidden
    | `Not_found -> NotFound
    | `Too_many_requests -> TooManyRequests
    | #Cohttp.Code.server_error_status -> OtherError body_str
    | #Cohttp.Code.redirection_status -> OtherError body_str
    | #Cohttp.Code.informational_status -> OtherError body_str
    | #Cohttp.Code.client_error_status -> OtherError body_str
    (* This might not be correct... *)
    | `Code _ -> OtherError body_str


end


