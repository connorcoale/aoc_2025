open Hardcaml
open Hardcaml.Signal

module I  = struct
  type 'a t = {
    in1 : 'a;
    in2 : 'a;
  } [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    out1 : 'a;
    out2 : 'a;
  } [@@deriving sexp_of, hardcaml]
end

let circuit _ (input : _ I.t) = 
  let xord = input.in1 ^: input.in2 in
  let nord = ~:(input.in1 |: input.in2) in
  { O.out1 = xord |: nord;
      out2 = nord; }

let hierarchical scope input =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"helper_03" circuit input