(* open Hardcaml.Signal *)
open Hardcaml.Signal

module I = struct
  type 'a t = { 
    clock      : 'a; 
    reset      : 'a; 
    cs         : 'a; 
    data       : 'a [@bits 8];
    data_valid : 'a;
  } [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { 
    solution_a     : 'a [@bits 32];
    solution_b     : 'a [@bits 32];
    solution_valid : 'a;
  } [@@deriving sexp_of, hardcaml]
end

(* let create (i : _ I.t) = 
  let data_qual = (Signal.repeat ~n:32 i.data_valid) &: i.data in
  { O.solution_a = data_qual } *)
let create (i : _ I.t) = 
  let valid32 = repeat i.data_valid 32 in
  let data_qual = valid32 &: uresize i.data 32 in
  { O.solution_a = data_qual;
    solution_b = data_qual;       (* placeholder *)
    solution_valid = i.data_valid }  (* example assignment *)
