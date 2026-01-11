open Hardcaml
open Part_03

(* Functor thing *)
module Solve_03_100 =
  Solve_03.Make(struct
    let bank_width = 100
    let num_banks  = 200
  end)

(* Top level circuit *)
module C =
  Circuit.With_interface
    (Solve_03_100.I)
    (Solve_03_100.O)

let scope = Scope.create ()

(* Instantiate circuit *)
let circuit =
  C.create_exn
    ~name:"solve_03_100"
    (Solve_03_100.circuit scope)

let output_mode = Rtl.Output_mode.To_file "../part_03.sv"

let () = Rtl.output ~output_mode 
  ~database:(Scope.circuit_database scope)
  Rtl.Language.Verilog 
  circuit
