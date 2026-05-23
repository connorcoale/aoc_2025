open Hardcaml
open Hardcaml.Signal
open Always

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

  (* Create state definitions *)
  module SMStates = struct
    type t =
      | IDLE_T
      | LOAD_T
      | CNT2_T
      | CNT12_T
      | DONE_T
    [@@deriving sexp_of, enumerate, compare]
  end

  let circuit scope (i : _ I.t) = 
    let spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in

    let data_as_int = uresize (i.data -: of_int ~width:8 48) 4 in
    let isNL                 = i.data ==: (of_int ~width:8 10) in

    (* State machine

                   │          
                   │          
                ┌──▼─┐        
            ┌───┼IDLE◄────┐   
            │   └────┘    │   
          ┌─▼──┐        ┌─┼──┐
        ┌─┼LOAD│◄──┐    │DONE│
        │ └────┘   │    └─▲──┘
     ┌──▼─┐     ┌──┼──┐   │   
     │CNT2┼─────►CNT12┼───┘   
     └────┘     └─────┘       
                           
    - In CNT2 and CNT12 we can be loading the next number (if there is one)
    - From CNT12 we can transition to DONE if cs is low and data_valid is low
      - otherwise, go back to LOAD
    - CNT2 to get part A
    - CNT12 to get part B
    - Stay in DONE until ...
    *)
    (* Declare fsm reg plus flags/control*)
    let sm         = State_machine.create (module SMStates) ~enable:vdd spec in
    let cnt2       = Variable.reg  ~width:4 spec in
    let cnt12      = Variable.reg  ~width:4 spec in
    let done_flag  = Variable.wire ~default:gnd in
    let loading    = Variable.wire ~default:gnd in 
    let solve_a    = Variable.wire ~default:gnd in 
    let solve_b    = Variable.wire ~default:gnd in 
    let init_solve = Variable.wire ~default:gnd in
    ignore (Scope.naming scope cnt2.value "cnt2");
    ignore (Scope.naming scope cnt12.value "cnt12");
    ignore (Scope.naming scope loading.value "loading");
    ignore (Scope.naming scope done_flag.value "done_flag");
    compile [
      sm.switch [
        IDLE_T, [
          done_flag <--. 0;
          when_ (i.cs &: i.data_valid) [
            loading <--. 1;
            sm.set_next LOAD_T
          ]
        ];
        LOAD_T, [
          loading <--. 1;
          cnt2    <--. 0;
          cnt12   <--. 0;
          when_ (isNL) [
            init_solve <--. 1;
            sm.set_next CNT2_T
          ]
        ];
        CNT2_T, [
          loading <-- (i.cs &: i.data_valid);
          solve_a <--. 1;
          cnt2    <-- (cnt2.value +:. 1);
          when_ (cnt2.value ==:. 1) [
            init_solve <--. 1;
            sm.set_next CNT12_T
          ]
        ];
        CNT12_T, [
          loading <-- (i.cs &: i.data_valid);
          solve_b <--. 1;
          cnt12   <-- (cnt12.value +:. 1);
          when_ (cnt12.value ==:. 11) [
            sm.set_next LOAD_T
          ];
          when_ (cnt12.value ==:. 11 &: ~:(i.cs &: i.data_valid)) [
            sm.set_next DONE_T
          ];
        ];
        DONE_T, [
          done_flag <--. 1;
          sm.set_next IDLE_T
        ];
      ]
    ];
    ignore (Scope.naming scope sm.current "fsm_state");

    (* Feed in all the characters into a bcd shift register to stage *)
    let bcd_in : Signal.t array = Array.make P.bank_width (zero 4) in
    for stage = 0 to P.bank_width-1 do
      let prev_value = bcd_in.(stage) in
      let stage_input = if stage = 0 then data_as_int else bcd_in.(stage - 1) in
      (* only pull in when the data is valid and it's not a NL *)
      let next_value = mux2 loading.value stage_input prev_value in
      bcd_in.(stage) <- reg spec next_value;
      ignore (Scope.naming scope bcd_in.(stage) ("shift_" ^ string_of_int stage))
    done;
  
    (* Stage the data to work on when it's a newline *)
    let bcd_staged : Signal.t array =
      Array.init P.bank_width (fun stage ->
        reg_fb spec ~width:4 ~f:(fun q ->
          mux2 isNL bcd_in.(stage) q
        )
      )
    in
    (* let bcd_staged : Signal.t array = Array.init P.bank_width (fun stage ->
      reg spec (mux2 isNL bcd_in.(stage) (zero 4))  (* zero 4 for init *)
    ) in *)
    for stage = 0 to P.bank_width - 1 do
      ignore (Scope.naming scope bcd_staged.(stage) ("staged_" ^ string_of_int stage))
    done;

    let part1_jolt_width = of_int ~width:7 2 in
    let part2_jolt_width = of_int ~width:7 12 in
    let jolt_idx       = mux2 (sm.is CNT12_T) part2_jolt_width part1_jolt_width -: (of_int ~width:7 1) in

    let%hw low_idx      = jolt_idx -: (uresize (mux2 (sm.is CNT12_T) cnt12.value cnt2.value) 7) in
    let%hw prev_idx     = wire 7 in
    let%hw prev_idx_reg = reg ~enable:vdd spec prev_idx in
    (* ignore (Scope.naming scope prev_idx_reg ("prev_idx_reg"));
    ignore (Scope.naming scope prev_idx ("prev_idx")); *)
    (* ignore (Scope.naming scope low_idx ("low_idx")); *)

    let fm_input : _ Find_max_n.I.t = 
      { 
        Find_max_n.I.bank = bcd_staged;
        prev_idx = prev_idx_reg;
        low_idx  = low_idx 
      }
    in
    let fm_output = Find_max_n.hierarchical scope fm_input in
    prev_idx <== mux2 init_solve.value (of_int ~width:7 (P.bank_width - 1)) fm_output.max_idx;

    { O.solution_a   = uresize fm_output.max     32;
      solution_b     = uresize fm_output.max_idx 32;
      solution_valid = sm.is DONE_T
    }

  let hierarchical scope =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ~scope ~name:"solve_03" circuit
end