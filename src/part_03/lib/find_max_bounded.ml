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
      bank     : 'a [@bits (4 * P.bank_width)];
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
    let nums : (Signal.t * Signal.t) array =
      Array.init P.bank_width (fun n ->
        let value = i.bank.:[(n*4 + 3, n*4)] in (* 4-bit slice *)
        let index = Signal.of_int ~width:7 n in

        let in_range =  (i.prev_idx >: index) &: (index >: i.low_idx) in
        let adj_v    = Signal.of_int ~width:4 0 in
        let adj_i    = Signal.of_int ~width:idx_width 0 in
        let value_adj = mux2 in_range value adj_v in
        let index_adj = mux2 in_range index adj_i in
        ignore (Scope.naming scope value ("num_" ^ string_of_int n));
        (value_adj, index_adj)
      )
    in

    (*
      TODO:
      - make a max() function which will take the two
        tuples and give the max, or if they're equal,
        the one with the highest idx
      - smart pipelining?
      - actually adhere to the range checking
        - maybe just insert 0 values with idx = 0 for
          invalid ranges (above prev_idx and below stage_num)
      - question: We could instantiate 12 of these in higher circuit
        and then wire together, but prob more efficient to
        instantiate one and do flopped feedback...
        latency vs. throughput tradeoff
    *)

    (* arr must be tuple of (value, idx) so that we can
       indicate for future bounded max selection which
       range should be checked
    *)
    let rec max_with_index arr =
      (* Base case: one element left *)
      if Array.length arr = 1 then arr.(0)
      else
        (* Construct new array, half as large as original.
           It is now:
             {
               max(arr.(0), arr.(1)),
               max(arr.(2), arr.(3)),
               ...
             }
           Then recurse over the tree.
        *)
        let pairs =
          Array.init ((Array.length arr + 1) / 2) (fun i ->
            if 2*i + 1 < Array.length arr then
              let (v1, idx1) = arr.(2*i) in
              let (v2, idx2) = arr.(2*i + 1) in
              let sel = v1 >=: v2 in
              let max_v   = mux2 sel v1   v2   in
              let max_idx = mux2 sel idx1 idx2 in
              (max_v, max_idx)
            else
              arr.(2*i)
          )
        in
        max_with_index pairs
    in

    let (max_value, max_index) = max_with_index nums in
    ignore (Scope.naming scope max_value "max_value");
    ignore (Scope.naming scope max_index "max_index");

    {
      O.max     = max_value;
      max_idx   = max_index +: i.prev_idx;
    }

  let hierarchical scope input =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical
      ~scope
      ~name:"find_max_bounded"
      circuit
      input

end