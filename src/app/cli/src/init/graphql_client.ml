open Core
open Async
open Signature_lib

let query query_obj port =
  let uri_string = "http://localhost:" ^ string_of_int port ^ "/graphql" in
  let variables_string = Yojson.Basic.to_string query_obj#variables in
  let body_string =
    Printf.sprintf {|{"query": "%s", "variables": %s}|} query_obj#query
      variables_string
  in
  let query_uri = Uri.of_string uri_string in
  let open Deferred.Let_syntax in
  let get_result () =
    let%bind _, body =
      Cohttp_async.Client.post
        ~headers:
          (Cohttp.Header.add (Cohttp.Header.init ()) "Accept"
             "application/json")
        ~body:(Cohttp_async.Body.of_string body_string)
        query_uri
    in
    let%map body = Cohttp_async.Body.to_string body in
    Yojson.Basic.from_string body
    |> Yojson.Basic.Util.member "data"
    |> query_obj#parse
  in
  match%bind Deferred.Or_error.try_with ~extract_exn:true get_result with
  | Ok e ->
      return e
  | Error e ->
      eprintf
        "Error connecting to daemon. You might need to start it, or specify a \
         custom --rest-port if it's already started.\n\
         Error message: %s\n"
        (Error.to_string_hum e) ;
      exit 17

module Encoders = struct
  let optional = Option.value_map ~default:`Null

  let uint64 value = `String (Unsigned.UInt64.to_string value)

  let uint32 value = `String (Unsigned.UInt32.to_string value)

  let public_key public_key =
    Yojson.Safe.to_basic @@ Public_key.Compressed.to_yojson public_key
end

module Decoders = struct
  let optional ~f = function `Null -> None | json -> Some (f json)

  let public_key json =
    Yojson.Basic.Util.to_string json
    |> Public_key.Compressed.of_base58_check_exn

  let optional_public_key = Option.map ~f:public_key

  let uint64 json =
    Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string
end

module Get_wallet =
[%graphql
{|
query getWallet {
  ownedWallets {
    public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
    balance {
      total @bsDecoder(fn: "Decoders.uint64")
    }
  }
}
|}]

module Snark_pool =
[%graphql
{|
query snarkPool {
  snarkPool {
  fee @bsDecoder(fn: "Decoders.uint64")
  prover @bsDecoder(fn: "Decoders.public_key")
  work_ids: workIds
}
}
|}]

module Set_snark_worker =
[%graphql
{|
mutation ($wallet: PublicKey) {
  setSnarkWorker (input : {wallet: $wallet}) {
      lastSnarkWorker @bsDecoder(fn: "Decoders.optional_public_key")
    }
  }
|}]

module Set_snark_work_fee =
[%graphql
{|
mutation ($fee: UInt64!) {
  setSnarkWorkFee(input: {fee: $fee}) {
    lastFee @bsDecoder(fn: "Decoders.uint64")
    }
}
|}]

module Cancel_user_command =
[%graphql
{|
mutation ($from: PublicKey, $to_: PublicKey, $fee: UInt64!, $nonce: UInt32) {
  sendPayment(input: {from: $from, to: $to_, amount: "0", fee: $fee, nonce: $nonce}) {
    payment {
      id
    }
  }
}
|}]

module Get_inferred_nonce =
[%graphql
{|
query nonce($public_key: PublicKey) {
  wallet(publicKey: $public_key) {
    inferredNonce
  }
}
|}]
