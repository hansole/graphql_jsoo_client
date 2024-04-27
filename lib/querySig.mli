(** This is the signature for usage with {{:
   https://beta.graphql-ppx.com/} graphql_ppx} generated modules

   It is a combination of the {{:
   https://beta.graphql-ppx.com/docs/definition} definition} and {{:
   https://beta.graphql-ppx.com/docs/operation} operation } signature.
   *)

module type Query = sig
  type t
  type t_variables

  module Raw : sig
    type t
    type t_variables
  end

  val query : string
  val parse : Raw.t -> t
  val serialize : t -> Raw.t
  val serializeVariables : t_variables -> Raw.t_variables
  val unsafe_fromJson : Yojson.Basic.t -> Raw.t
  val toJson : Raw.t -> Yojson.Basic.t
  val variablesToJson : Raw.t_variables -> Yojson.Basic.t
end
;;
