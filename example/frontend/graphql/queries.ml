
[%graphql {|
  query UsersQuery($id: Int!) {
    users(id :$id) {
      name
    }
  }
|}]
;;

[%graphql {|
  query UsersQueryFull {
    users {
      id
      name
    }
  }
|}]
;;


[%graphql {|
  subscription
   PingPongCount($until: Int!) {
     count(until : $until)
     }
|}]
;;

[%graphql {|
  subscription
   MyCounter {
     counter
     }
|}]
;;

[%graphql
  {|
  mutation Update($value: Int!) {
    update(value: $value)
  }
|}]
;;

