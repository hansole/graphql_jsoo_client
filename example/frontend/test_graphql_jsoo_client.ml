
let test_mutation_ws con value =
  let module Update = Test_frontend_graphql.Queries.Update in
  let module Cl = Graphql_jsoo_client.Client.Make (Update) in
  let v = Update.makeVariables ~value:value () in
  let%lwt r = Cl.query con v in
  match r with
  | Success _res ->
    Lwt.return_unit
  | _ ->
    Lwt.return_unit

let rec test_counter con stop_num =
  let module MyCounter = Test_frontend_graphql.Queries.MyCounter in
  let module Cl = Graphql_jsoo_client.Client.Make (MyCounter) in

  let uuid_ref = ref "" in
  let handler_test (m : MyCounter.t ) =
    let () =
      if (m.counter mod 100) = 0 then
        Printf.printf "Ping pong counter '%d'\n%!" m.counter
      else
        ()
    in
    Lwt.ignore_result (
      if m.counter >= stop_num then
        let%lwt () = Cl.unsubscribe con !uuid_ref in
        Printf.printf "Ping pong counter will wait for 10 sec before continuing%!";
        let%lwt () = Js_of_ocaml_lwt.Lwt_js.sleep 10.0 in
        test_counter con (m.counter + 300)
      else
        test_mutation_ws con (m.counter + 1)
    )
  in
  let v = MyCounter.makeVariables () in
  let%lwt uuid = Cl.subscribe con v handler_test in
  uuid_ref := uuid;
  Printf.printf "PingPong subscribed with id '%s' stop_num '%d'\n%!" uuid stop_num;
  Lwt.return_unit

let a () =
  let module PingPongCount = Test_frontend_graphql.Queries.PingPongCount in
  let module Cl = Graphql_jsoo_client.Client.Make (PingPongCount) in
  let module UserQueryFull = Test_frontend_graphql.Queries.UsersQueryFull in
  let module ClUserQueryFull = Graphql_jsoo_client.Client.Make (UserQueryFull) in

  let module UserQuery = Test_frontend_graphql.Queries.UsersQuery in
  let module ClUserQuery = Graphql_jsoo_client.Client.Make (UserQuery) in

  let%lwt con = Graphql_jsoo_client.Client.connect
      ~trace:Graphql_jsoo_client.Client.trace_console
      "graphql" in

  let%lwt r = ClUserQueryFull.query con () in
  let%lwt () = 
    match r with 
    | Success res ->
      Array.iter (fun (user : UserQueryFull.t_users) ->
          let n = user.name  in
          Printf.printf "User '%s'%!" n ) res.users;
      Lwt.return_unit
    | _ ->
      Lwt.return_unit
  in

  let v = UserQuery.makeVariables ~id:2 () in
  let%lwt r = ClUserQuery.query con v in
  let%lwt () = 
    match r with 
    | Success res ->
      Array.iter (fun (user : UserQuery.t_users) ->
          let n = user.name  in
          Printf.printf "User wit id '2' is '%s'%!" n ) res.users;
      Lwt.return_unit
    | _ ->
      Lwt.return_unit
  in


  let%lwt () = test_counter con 300 in

  let v = PingPongCount.makeVariables ~until:10 () in
  let handler_test (m : PingPongCount.t ) =
    Printf.printf "MyCount '%d'%!" m.count
  in

  let%lwt _uuid = Cl.subscribe con v handler_test in
  Lwt.return_unit




let () = Lwt.ignore_result(a ())
