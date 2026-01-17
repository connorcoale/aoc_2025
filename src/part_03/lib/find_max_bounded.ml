open Hardcaml
open Hardcaml.Signal

(* Params *)
module type Params = sig
  val bank_width : int
end

(* The functor (to be called in other modules) *)
module Make (P : Params) = struct
  (* Derived parameters *)
  let idx_width = Bits.address_bits_for P.bank_width
  (* IO *)
  module I = struct
    type 'a t = {
      (* Flattened array of 4-bit values: bank_width entries total *)
      bank     : 'a array; [@length P.bank_width] [@bits 4]
      prev_idx : 'a [@bits idx_width];
      low_idx  : 'a [@bits idx_width];
    } [@@deriving sexp_of, hardcaml]
  end
  module O = struct
    type 'a t = {
      max     : 'a [@bits 4];
      max_idx : 'a [@bits 7];
      (* valid : 'a;  (* left commented out for now *) *)
    } [@@deriving sexp_of, hardcaml]
  end
  (* The actual circuit implementation *)
  let circuit scope (i : _ I.t) =

    (* First create the list of input numbers, with indices *)
    let nums : (Signal.t * Signal.t) array =
      Array.init P.bank_width (fun n ->
        let value = i.bank.(n) in (* 4-bit slice *)
        let index = Signal.of_int ~width:7 n in

        (* if not in the range determind by prev_idx and low_idx, force the value and index to 0 *)
        let in_range =  (i.prev_idx >: index) &: (index >: i.low_idx) in
        let adj_v    = Signal.of_int ~width:4 0 in
        let adj_i    = Signal.of_int ~width:idx_width 0 in
        let value_adj = mux2 in_range value adj_v in
        let index_adj = mux2 in_range index adj_i in
        ignore (Scope.naming scope value ("num_" ^ string_of_int n));
        ignore (Scope.naming scope in_range ("in_range_" ^ string_of_int n));
        ignore (Scope.naming scope value_adj ("value_adj_" ^ string_of_int n));
        ignore (Scope.naming scope index_adj ("index_adj_" ^ string_of_int n));
        (value_adj, index_adj)
      )
    in

    (* Get the max based on value, then based on idx if tie *)
    let pair_max_with_index (lv, li) (rv, ri) =
      let choose_left =
        (lv >: rv) |:
        ((lv ==: rv) &: (li >: ri))
      in
      ( mux2 choose_left lv rv
      , mux2 choose_left li ri
      )
    in
    let reduce_max_with_index = function
      | [x] -> x
      | [x; y] -> pair_max_with_index x y
      | xs ->
          let x = List.hd xs in
          let rest = List.tl xs in
          List.fold_left pair_max_with_index x rest
    in
    let (max_value, max_index) = tree ~arity:2 ~f:reduce_max_with_index (Array.to_list nums) in
    ignore (Scope.naming scope max_value "max_value");
    ignore (Scope.naming scope max_index "max_index");

    {
      O.max     = max_value;
      max_idx   = max_index;
    }

  let hierarchical scope input =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical
      ~scope
      ~name:"find_max_bounded"
      circuit
      input
end