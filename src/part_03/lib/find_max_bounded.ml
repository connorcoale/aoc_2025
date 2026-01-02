open Hardcaml
open Hardcaml.Signal

module I = struct
  type 'a t = { 
    (* clock      : 'a;  *)
    (* prev_idx   : 'a [@bits 7]; (* 7 bits to contain 100 chars *) *)
    bank       : 'a [@bits 4*100];
    (* en         : 'a; *)
  } [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { 
    max        : 'a [@bits 4];
    max_idx    : 'a [@bits 7];
    (* valid      : 'a; *)
  } [@@deriving sexp_of, hardcaml]
end

let circuit scope (i : _ I.t) =

  let nums : (Signal.t * Signal.t) array =
    Array.init 100 (fun n ->
      let value = i.bank.:[(n*4 + 3, n*4)] in          (* 4-bit slice *)
      let index = Signal.of_int ~width:7 n in           (* 7-bit index for 0..99 *)
      ignore (Scope.naming scope value ("num_" ^ string_of_int n));
      (value, index)
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
    (* base case, recursed down to one element only *)
    if Array.length arr = 1 then arr.(0)
    else
      (*  Construct new array, half as large as original.
          It is now:
            {
              max(arr.(0), arr.(1)), 
              max(arr.(2), arr.(3)), 
              ... 
              max(arr.(n-2), arr.(n-1))
            }
          Then recurse over the tree
      *)
      let pairs =
        Array.init ((Array.length arr + 1)/2) (fun i ->
          if 2*i+1 < Array.length arr then
            let (v1, idx1) = arr.(2*i) in
            let (v2, idx2) = arr.(2*i+1) in
            let max_v   = mux2 (v1 >=: v2) v1 v2 in
            let max_idx = mux2 (v1 >=: v2) idx1 idx2 in
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

  { O.max = max_value;
    max_idx   = max_index; 
  }


let hierarchical scope input =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"find_max_bounded" circuit input