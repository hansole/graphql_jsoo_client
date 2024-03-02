open! Js_of_ocaml

module Connection = struct
  type response = 
    | Success of Yojson.Basic.t
    | Unauthorized
    | Forbidden
    | NotFound
    | TooManyRequests
    | OtherError of string

  type operation =
    | Query of ((response -> unit) * Yojson.Basic.t option )
    | Subscribe of (Yojson.Basic.t -> unit)
    | Mutation of string 

  type ws_connection = {
    ws : WebSockets.webSocket Js.t;
    handlers : (string, (operation)) Hashtbl.t;
  }

  let url = Uri.of_string "/graphql"

  let connection_init_message id =
    `Assoc [
      "type", `String "connection_init";
      "id", `String id;
    ]
    |> Yojson.Basic.to_string


  let default_query =
    "{\\n  users {\\n    name\\n    id\\n  }\\n}\\n"



  let ws_message_handler handlers ev =
    let msg = Js.to_string ev##.data in
    (* Printf.printf "HANS: ws_message_handler message '%s'%!" msg ; *)
    let open Yojson.Basic.Util in
    let jmsg = Yojson.Basic.from_string msg in
    let type_ = jmsg |> member "type" |> to_string in
    let id = jmsg |> member "id" |> to_string in
    if Hashtbl.mem handlers id then
      let handler  = Hashtbl.find handlers id in
      match handler with
      | Query (h, o) -> 
        begin
          if type_ = "next" then
            begin 
              let payload = jmsg |> member "payload" in
              let body_json = member "data" payload in
              (* let body_unsafe = Q.unsafe_fromJson body_json in
               * let body = Q.parse body_unsafe in *)
              Hashtbl.replace handlers id (Query(h, (Some body_json)));
              Js._true
            end
          else if type_ = "complete" then
            begin
              Hashtbl.remove handlers id;
              match o with
              | None ->
                let () = h (OtherError "complete without any data yet") in
                Js._true
              | Some body ->
                let () = h (Success body) in
                Js._true
            end
          else
            begin
              Hashtbl.remove handlers id;
              Printf.printf "Unknown message type '%s'%!" type_;
              Js._true
            end
        end
      | Subscribe h -> 
        begin
          if type_ = "next" then
            begin 
              let payload = jmsg |> member "payload" in
              let body_json = member "data" payload in
              (* let body_unsafe = Q.unsafe_fromJson body_json in
               * let body = Q.parse body_unsafe in *)
              let () = h body_json in
              (* Hashtbl.replace handlers id (Query(h, (Some body))); *)
              Js._true
            end
          else if type_ = "complete" then
            begin
              Hashtbl.remove handlers id;
              (* match o with
               * | None ->
               *   let () = Lwt.wakeup_later h (OtherError "complete without any data yet") in
               *   Js._true
               * | Some body ->
               *   let () = Lwt.wakeup_later h (Success body) in *)
              Js._true
            end
          else
            begin
              Hashtbl.remove handlers id;
              Printf.printf "Unknown message type '%s'%!" type_;
              Js._true
            end
        end
      | Mutation _h -> 
        let () = () in
        Js._true
    else
      begin 
        Printf.printf "No handler for id '%s' for message type '%s'%!" id type_;
        Js._true
      end

  let connect () =
    let addr = Url.Current.host in
    let port = Option.get (Url.Current.port) in
    let url = Printf.sprintf "ws://%s:%d/graphql_ws" addr port in
    let () = Printf.printf "COnnecting to port %s\n%!" url in
    let ws = new%js WebSockets.webSocket_withProtocol
      (Js.string url) 
      (Js.string "graphql-transport-ws")
    in
    let ww, s = Lwt.wait () in
    let con = {ws = ws; 
               handlers = Hashtbl.create 11
              }
    in
    let ev_unl_id =
      Dom_html.addEventListener Dom_html.window Dom_html.Event.unload
        (Dom_html.handler (fun _ev ->
             (Printf.printf "Window event: unload!" ; ws##close ; Js._true)))
        Js._true
    in
    ws##.onopen := Dom.handler (fun _ev -> begin
          Printf.printf "WebSocket connected.%!" ;
          ws##send (Js.string (connection_init_message "foobar"));
          (* if is_debug then show_message "WebSocket connected." ; *)
          Js._true
        end) ;
    ws##.onmessage := Dom.handler (fun ev -> begin
          let msg = Js.to_string ev##.data in
          (* Printf.printf "message '%s'%!" msg ; *)
          let jmsg = Yojson.Safe.from_string msg in
          let open Yojson.Safe.Util in
          let type_ = jmsg |> member "type" |> to_string in
          let () = 
            if type_ = "connection_ack" then
              ws##.onmessage := Dom.handler (ws_message_handler con.handlers);
              Lwt.wakeup_later s 
                (con);
          in
          Js._true
        end);
    ws##.onclose := Dom.handler (fun _ev -> begin
          Printf.printf "WebSocket connection closed!%!" ;
          Dom_html.removeEventListener ev_unl_id ;
          Js._true
          end) ;
    ws##.onerror := Dom.handler (fun _ev -> begin
          Printf.printf "WebSocket error!%!" ;
          Js._true
        end) ;
    ww
end
