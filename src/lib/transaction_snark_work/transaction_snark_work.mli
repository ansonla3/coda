open Core_kernel
open Currency
open Signature_lib

module Statement : sig
  type t = Transaction_snark.Statement.t list [@@deriving yojson, sexp]

  include Hashable.S with type t := t

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving yojson, version, sexp, bin_io]

        include Hashable.S_binable with type t := t
      end
    end
    with type V1.t = t

  val gen : t Quickcheck.Generator.t

  val compact_json : t -> Yojson.Safe.json

  val work_ids : t -> int list
end

module Info : sig
  type t =
    { statements: Statement.Stable.V1.t
    ; work_ids: int list
    ; fee: Fee.Stable.V1.t
    ; prover: Public_key.Compressed.Stable.V1.t }
  [@@deriving to_yojson, sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving to_yojson, version, sexp, bin_io]
      end
    end
    with type V1.t = t
end

(* TODO: The SOK message actually should bind the SNARK to
       be in this particular bundle. The easiest way would be to
       SOK with
       H(all_statements_in_bundle || fee || public_key)
    *)

type t =
  {fee: Fee.t; proofs: Ledger_proof.t list; prover: Public_key.Compressed.t}
[@@deriving sexp, to_yojson]

val fee : t -> Fee.t

val info : t -> Info.t

module Stable :
  sig
    module V1 : sig
      type t [@@deriving sexp, bin_io, to_yojson, version]
    end
  end
  with type V1.t = t

type unchecked = t

module Checked : sig
  type nonrec t = t =
    {fee: Fee.t; proofs: Ledger_proof.t list; prover: Public_key.Compressed.t}
  [@@deriving sexp, to_yojson]

  module Stable : module type of Stable

  val create_unsafe : unchecked -> t
end

val forget : Checked.t -> t

val proofs_length : int
