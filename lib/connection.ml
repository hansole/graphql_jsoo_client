
open! Js_of_ocaml

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

type state =
  | Connecting
  | Connected
  | Disconnecting
  | Disconnected


type handler = {
  added_ts : float;
  operation : operation;
}

type t = {
  mutable state : state;
  ws : WebSockets.webSocket Js.t;
  handlers : (string, (handler)) Hashtbl.t;
}

let string_of_state con =
  match con.state with
  | Connected -> "connected"
  | Connecting -> "connecting"
  | Disconnected -> "disconnected"
  | Disconnecting -> "disconnecting"


let connection_init_message id =
  `Assoc [
    "type", `String "connection_init";
    "id", `String id;
  ]
  |> Yojson.Basic.to_string

let pong_message payload =
  `Assoc [
    "type", `String "pong";
    "payload", payload;
  ]
  |> Yojson.Basic.to_string

let ping_message payload =
  `Assoc [
    "type", `String "ping";
    "payload", payload;
  ]
  |> Yojson.Basic.to_string


let add_handler con uuid op =
    (* Hashtbl.add con.handlers uuid op *)
  Hashtbl.replace con.handlers uuid 
    {added_ts = Unix.gettimeofday ();
     operation = op;
    }

let remove_handler con uuid =
    Hashtbl.remove con.handlers uuid

let trace_console str =
  Printf.printf "%s\n" str

let trace_none _str =
  ()

let ws_message_handler trace con ev =
  (* let msg = Js.to_string ev##.data in *)
  let open Yojson.Basic.Util in
  let jmsg = Js.to_string ev##.data |> Yojson.Basic.from_string in
  let type_ = jmsg |> member "type" |> to_string in
  if type_ = "ping" || type_ = "pong" then 
    begin
      match type_ with
      | "pong" ->
        trace (Printf.sprintf "Pong packet recived");
        Js._true
      | _a ->
        (* Must be ping packet *)
        let payload = Yojson.Basic.Util.member "payload" jmsg in
        let pong_msg = pong_message payload in
        con.ws##send (Js.string (pong_msg));
        Js._true
    end 
  else 
    begin
      let id = jmsg |> member "id" |> to_string in
      if Hashtbl.mem con.handlers id then
        let handler  = Hashtbl.find con.handlers id in
        match handler.operation with
        | Query (h, o) -> 
          begin
            if type_ = "next" then
              begin 
                let payload = jmsg |> member "payload" in
                let body_json = member "data" payload in
                add_handler con id (Query(h, (Some body_json)));
                Js._true
              end
            else if type_ = "complete" then
              begin
                remove_handler con id;
                match o with
                | None ->
                  let () = h (OtherError "Query: complete without any data yet") in
                  Js._true
                | Some body ->
                  let () = h (Success body) in
                  Js._true
              end
            else if type_ = "error" then
              begin
                let payload = jmsg |> member "payload" |> to_string in
                remove_handler con id;
                trace (Printf.sprintf "Query: Error for id '%s' '%s'" id payload);
                let () = h (OtherError (Js.to_string ev##.data)) in
                Js._true
              end
            else
              begin
                remove_handler con id;
                let () = h (OtherError (Js.to_string ev##.data)) in
                trace (Printf.sprintf "Query: Unknown message type '%s'%!" type_);
                Js._true
              end
          end
        | Subscribe h -> 
          begin
            if type_ = "next" then
              begin
                let payload = jmsg |> member "payload" in
                let body_json = member "data" payload in
                let () = h body_json in
                Js._true
              end
            else if type_ = "complete" then
              begin
                remove_handler con id;
                trace (Printf.sprintf "Subscribe: Complete for '%s'" id);
                Js._true
              end
            else if type_ = "error" then
              begin
                let payload = jmsg |> member "payload" |> to_string in
                remove_handler con id;
                trace (Printf.sprintf "Subscribe: Error for id '%s' '%s'" id payload);
                Js._true
              end
            else
              begin
                remove_handler con id;
                trace (Printf.sprintf "Subscribe: Unknown message type '%s'%!" type_);
                Js._true
              end
          end
        | Mutation _h -> 
          let () = () in
          Js._true
      else
        begin 
          trace (Printf.sprintf "No handler for id '%s' for message type '%s'%!" id type_);
          Js._true
        end
    end

let connect ?(trace=trace_none) ?(protocol="ws") ?(host = None) ?(port = None) path =
  let addr =
    match host with
    | None -> Url.Current.host
    | Some h -> h
  in
  let port =
    match port with
    | None -> 
      begin 
        try
          let p = Option.get Url.Current.port in
          Printf.sprintf ":%d" p
        with _ ->
          ""
      end
    | Some p -> Printf.sprintf ":%d"p
  in

  let url = Printf.sprintf "%s://%s%s/%s" protocol addr port path in
  let () = trace (Printf.sprintf "Connecting to port %s\n%!" url) in
  let ws = new%js WebSockets.webSocket_withProtocol
    (Js.string url) 
    (Js.string "graphql-transport-ws")
  in
  let ww, s = Lwt.wait () in
  let con = {
    state = Connecting;
    ws = ws; 
    handlers = Hashtbl.create 11
  }
  in
  let ev_unl_id =
    Dom_html.addEventListener Dom_html.window Dom_html.Event.unload
      (Dom_html.handler (fun _ev ->
            (Printf.printf "Window event: unload!" ;
             con.state <- Disconnecting;
             ws##close ; Js._true)))
      Js._true
  in
  ws##.onopen := Dom.handler (fun _ev -> begin
        trace (Printf.sprintf "WebSocket connected.%!");
        con.state <- Connected;
        let uuid = Uuidm.(v `V4) |> Uuidm.to_string in
        ws##send (Js.string (connection_init_message uuid));
        trace (Printf.sprintf "Sent init message.%!");
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
            ws##.onmessage := Dom.handler (ws_message_handler trace con);
          Lwt.wakeup_later s 
            (con);
        in
        Js._true
      end);
  ws##.onclose := Dom.handler (fun _ev -> begin
        trace (Printf.sprintf "WebSocket connection closed!%!");
        con.state <- Disconnected;
        Dom_html.removeEventListener ev_unl_id ;
        Js._true
      end) ;
  ws##.onerror := Dom.handler (fun _ev -> begin
        trace (Printf.sprintf "WebSocket error!%!");
        Js._true
      end) ;
  ww

let disconnect con =
  if con.state = Connected then
    begin
      con.state <- Disconnecting;
      con.ws##close
    end
  else
    begin
      failwith ("disconnect on WebSocket that is not connected");
    end

let send con json =
  if con.state = Connected then
    begin
      con.ws##send (Js.string (json));
      ()
    end
  else
    begin
      failwith ("Send on WebSocket that is not in 'connected' state");
    end

let debug_list_handlers con =
  Hashtbl.fold (fun k v acc ->
      let kind = match v.operation with
        | Query _ -> "query"
        | Subscribe _ -> "subscibe"
        | Mutation _ -> "mutation"
      in
      (k, v.added_ts, kind)::acc) con.handlers []
