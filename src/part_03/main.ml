open Hardcaml
open Part_03

module Part_03Circuit = Circuit.With_interface(Solve_03.I)(Solve_03.O)
  
let scope = Scope.create ()
let circuit = 
  Part_03Circuit.create_exn ~name:"part_03" (Solve_03.circuit scope)
let output_mode = Rtl.Output_mode.To_file "../part_03.sv"

let () = Rtl.output ~output_mode 
  ~database:(Scope.circuit_database scope)
  Rtl.Language.Verilog circuit
