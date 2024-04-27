type user = {id : int; name : string}

let hardcoded_users = [
  {id = 1; name = "alice"};
  {id = 2; name = "bob"};
  {id = 3; name = "hans"};
  {id = 4; name = "ole"};

]

(* A counter that will send a new value periodicly to a subscription
   until it reach a limit *)
let count until =
  let stream, push = Lwt_stream.create () in
  let close () = push None in

  Lwt.async begin fun () ->
    let rec loop n =
      let%lwt () = Lwt_unix.sleep 0.5 in
      if n > until then 
        (close (); Lwt.return_unit)
      else 
        (push (Some n); loop (n + 1))
    in
    loop 1
  end;

  stream, close

(* User schema to show how to use queries *)
let user :  (Dream.request, user option) Graphql_lwt.Schema.typ =
  Graphql_lwt.Schema.(obj "users"
    ~fields:[
      field "id"
        ~typ:(non_null int)
        ~args:Arg.[]
        ~resolve:(fun _info user -> user.id);
      field "name"
        ~typ:(non_null string)
        ~args:Arg.[]
        ~resolve:(fun _info user -> user.name);
    ])

(* Will send the contnent of the counter and wait for new values
   signaled to it, and send the signaled value *)
let counter counter_data_cond counter_data  =
  (* counter_data_cond := (Lwt_condition.create ()); *)
  Dream.log "Initialize counter";
  let stream, push = Lwt_stream.create () in
  let on_close = Lwt_stream.closed stream in
  let close () = 
    Dream.log "Closing counter stream"; push None 
  in
  Lwt.async (fun () -> 
      let%lwt () = on_close in
      Dream.log "Stream has been closed!!!";
      Lwt_condition.signal counter_data_cond 0;
      Lwt.return_unit);
  push (Some !counter_data);
  Lwt.async begin fun () ->
    (* Main loop *)
    let rec loop () =
      let%lwt n = Lwt_condition.wait (counter_data_cond) in
      try 
        push (Some n);
        loop ()
      with Lwt_stream.Closed ->
        Dream.log "Stream closed exception";
        Lwt.return_unit
    in
    loop ()
  end;
  stream, close

(* Receive mutations update the value and signal the counter (and its
   subscribers) *)
let mutation_update counter_data_cond counter_data value =
  if !counter_data < value then
    begin
      counter_data := value;
      Lwt_condition.signal counter_data_cond value;
      Lwt.return true
    end 
  else 
    Lwt.return true

(* GraphQL schema used in this example *)
let schema =
  let sessions = Hashtbl.create 101 in
  Graphql_lwt.Schema.(schema [
    field "users"
      ~typ:(non_null (list (non_null user)))
      ~args:Arg.[arg "id" ~typ:int]
      ~resolve:(fun _info () id ->
        match id with
        | None -> hardcoded_users
        | Some id' ->
          match List.find_opt (fun {id; _} -> id = id') hardcoded_users with
          | None -> []
          | Some user -> [user]);
  ]
    ~subscriptions:[
      subscription_field "count"
        ~typ:(non_null int)
        ~args:Arg.[arg "until" ~typ:(non_null int)]
        ~resolve:(fun _info until ->
          Lwt.return (Ok (count until)));
      subscription_field "counter"
        ~typ:(non_null int)
        ~args:Arg.[]
        ~resolve:(fun info ->
            let key = Dream.header info.ctx "Sec-WebSocket-Key" |> Option.get in
            let counter_data_cond, counter_data =
              if Hashtbl.mem sessions key then
                  Hashtbl.find sessions key
              else 
                let counter_data_cond = Lwt_condition.create () in
                let counter_data = ref 0 in
                Hashtbl.add sessions key (counter_data_cond, counter_data);
                counter_data_cond, counter_data
            in
            Dream.log "New subscription for counter for key '%s'" key;
            Lwt.return (Ok (counter counter_data_cond counter_data)));

    ]
      ~mutations:
        [
          io_field "update" ~typ:(non_null bool)
            ~args:
              Arg.
                [
                  arg "value" ~typ:(non_null int);
                ]
            ~resolve:(fun info () value ->
            let key = Dream.header info.ctx "Sec-WebSocket-Key" |> Option.get in
            let counter_data_cond, counter_data =
              if Hashtbl.mem sessions key then
                  Hashtbl.find sessions key
              else 
                let counter_data_cond = Lwt_condition.create () in
                let counter_data = ref 0 in
                Hashtbl.add sessions key (counter_data_cond, counter_data);
                counter_data_cond, counter_data
            in
              Lwt_result.ok (mutation_update counter_data_cond 
                               counter_data value));
        ]
)

let home =
  <html>
    <head>
      <script src="static/test_graphql_jsoo_client.bc.js"></script>
    </head>
    <body>
      <p>Testing...</p>
    </body>
  </html>

let () =
  Dream.run
  @@ Dream.logger
  @@ Dream.router [

    Dream.get "/static/**" (Dream.static "./static/");

    Dream.get "/"
      (fun _ -> Dream.html home);

    Dream.any "/graphql" (Dream.graphql Lwt.return schema);

  ]
