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

  let spec =
    Reg_spec.create
      ~clock:i.clock
      ~reset:i.reset
      () 
  in

  let helper_in = 
    {
    Helper_03.I.in1 = i.cs;
                in2 = i.data_valid
    }
  in

  let helper = Helper_03.hierarchical scope helper_in in
  let out1_q = reg spec helper.out1 in
  let out1_q32 = 
    let r = reg spec (uresize out1_q 32) in
    Scope.naming scope r "out1_q32"
  in

  let shift_regs : Signal.t array = Array.make 4 (zero 4) in
  for stage = 0 to 3 do
    let input = if stage = 0 then uresize out1_q 4 else shift_regs.(stage - 1) in
    shift_regs.(stage) <- reg spec input;
    ignore (Scope.naming scope shift_regs.(stage) ("shift_" ^ string_of_int stage))
  done;

  let shift_3 = uresize (shift_regs.(3)) 32 in
  let data_qual = out1_q32 &: uresize i.data 32 &: shift_3 in


  { O.solution_a = data_qual;
    solution_b = data_qual;
    solution_valid = i.data_valid }

let hierarchical scope =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"solve_03" circuit
;;