open Hardcaml
open Hardcaml.Signal

(* functor calling the Make function, which is parameterized with the bank width *)
module Find_max_100 = Find_max_bounded.Make(struct let bank_width = 100 end)

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

  let test_val = of_int ~width:400 0x48921002 in
  let test_val2 = of_int ~width:(Bits.address_bits_for 100) 44 in
  let test_val3 = of_int ~width:(Bits.address_bits_for 100) 10 in

  (* We have a functor up above, so by just defining the input and 
  then an output which is derived from the functor(input), we get the
  module instantation
  *)
  let fm_input : _ Find_max_100.I.t = 
    { 
      Find_max_100.I.bank = test_val;
      prev_idx = test_val2 ;
      low_idx  = test_val3
    }
  in
  let fm_output                     = Find_max_100.hierarchical scope fm_input in

  { O.solution_a = data_qual +: uresize fm_output.max 32;
    solution_b = uresize fm_output.max_idx 32;
    solution_valid = i.data_valid }

let hierarchical scope =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"solve_03" circuit
;;