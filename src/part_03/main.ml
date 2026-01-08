open Hardcaml
open Part_03

module Part_03Circuit = Circuit.With_interface(Solve_03.I)(Solve_03.O)
  
(* let scope = Scope.create ()
let circuit = 
  Part_03Circuit.create_exn ~name:"part_03" (Solve_03.circuit scope) *)

module Find_max_100 =
  Find_max_bounded.Make(struct let bank_width = 100 end)

module C =
  Circuit.With_interface
    (Find_max_100.I)
    (Find_max_100.O)

let scope = Scope.create ()

let circuit =
  C.create_exn
    ~name:"find_max_bounded_100"
    (Find_max_100.circuit scope)


let output_mode = Rtl.Output_mode.To_file "../part_03.sv"

let () = Rtl.output ~output_mode 
  ~database:(Scope.circuit_database scope)
  Rtl.Language.Verilog circuit
