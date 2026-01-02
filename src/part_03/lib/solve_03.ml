open Hardcaml
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

let circuit scope (i : _ I.t) = 

  let helper_in = 
    {
    Helper_03.I.in1 = i.cs;
                in2 = i.data_valid
    }
  in

  let helper = Helper_03.hierarchical scope helper_in in

  let valid32 = repeat helper.out1 32 in
  let data_qual = valid32 &: uresize i.data 32 in

  { O.solution_a = data_qual;
    solution_b = data_qual;
    solution_valid = i.data_valid }

let hierarchical scope =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"solve_03" circuit
;;