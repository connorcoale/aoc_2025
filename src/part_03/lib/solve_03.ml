open Hardcaml
open Hardcaml.Signal

(* Params *)
module type Params = sig
  val bank_width : int
  val num_banks  : int
end

(* Functor thing *)
module Make (P : Params) = struct

  (* Need a parameterized size for the max-finder, can declare here and instantiate later *)
  module Find_max_n = Find_max_bounded.Make(struct
    let bank_width = P.bank_width
  end)

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
    let spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in

    let data_as_int = uresize (i.data -: of_int ~width:8 48) 4 in
    let isNL                 = i.data ==: (of_int ~width:8 10) in

    (* Feed in all the characters into a bcd shift register to stage *)
    let bcd_in : Signal.t array = Array.make P.bank_width (zero 4) in
    for stage = 0 to P.bank_width-1 do
      let prev_value = bcd_in.(stage) in
      let stage_input =
        if stage = 0 then data_as_int else bcd_in.(stage - 1)
      in
      (* only pull in when the data is valid and it's not a NL *)
      let next_value = mux2 (i.data_valid &: ~: isNL) stage_input prev_value in
      bcd_in.(stage) <- reg spec next_value;
      ignore (Scope.naming scope bcd_in.(stage)
                ("shift_" ^ string_of_int stage))
    done;
  
    (* Stage the data to work on when it's a newline *)
    let bcd_staged : Signal.t array = Array.init P.bank_width (fun stage ->
      reg spec (mux2 isNL bcd_in.(stage) (zero 4))  (* zero 4 for init *)
    ) in
    for stage = 0 to P.bank_width - 1 do
      ignore (Scope.naming scope bcd_staged.(stage)
                ("staged_" ^ string_of_int stage))
    done;

    (* HOW is there not an easier way to flatten an array of signals??? *)
    let bcd_staged_flat =
      match Array.to_list bcd_staged with
      | [] -> failwith "bcd_staged cannot be empty"
      | hd :: tl ->
          List.fold_right (fun s acc -> s @: acc) tl hd
    in
    ignore (Scope.naming scope bcd_staged_flat "bcd_staged_flat");


    (* Feed the data into the max-finder *)
    (* TODO: Need to loop it back the 2 or 12 times for the problem in order to successively close
    the bounding in order to solve the problem *)
    let test_prev_idx = of_int ~width:7 100 in
    let test_low_idx = of_int ~width:7 12 in
    let fm_input : _ Find_max_n.I.t = 
      { 
        Find_max_n.I.bank = bcd_staged_flat;
        prev_idx = test_prev_idx ;
        low_idx  = test_low_idx
      }
    in
    let fm_output = Find_max_n.hierarchical scope fm_input in

    { O.solution_a = uresize fm_output.max 32;
      solution_b = uresize fm_output.max_idx 32;
      solution_valid = i.data_valid 
    }

  let hierarchical scope =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ~scope ~name:"solve_03" circuit
end