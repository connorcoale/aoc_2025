open Hardcaml
open Part_03

module Part_03Circuit = Circuit.With_interface(Datapath.I)(Datapath.O)

let circuit = Part_03Circuit.create_exn Datapath.create ~name:"datapath"

let output_mode = Rtl.Output_mode.To_file "../part_03.sv"

(* let output_hdl     = Rtl.Language.Verilog *)

(* let () = Rtl.print Verilog circuit *)
let () = Rtl.output ~output_mode Rtl.Language.Verilog circuit
