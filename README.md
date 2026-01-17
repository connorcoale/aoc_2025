# AOC 2025
## HOW TO:
### How to run TB(s)
```
make run_sim_<n> # where n is 01, 02, 03
make run_sim_top
make run_sim_all
```
### How to symthesize with yosys
```
make syn
```
### How to compile and flash with Vivado
```
make generate_bitstream
make flash_bitstream
```
Keep in mind that I did most of this development on my new MacOS machine, so I haven't recently tested the flow with an x86 machine that can run Vivado.
### Otherwise
Just check the Makefile. It's a bit of a mess, and was definitely an exploration for me in terms of discovering how to make things as reusable as possible. It's not perfect (I seem to be recompiling my Chisel and Hardcaml sources for every sim regardless of true dependencies), but it's a good start.

## ABOUT
I wanted to try to solve every problem with a new HDL (or alt-HDL). However, I ran out of time to get even close to done. Turns out it's a lot harder to learn a new language every week or so. 

What I succeeded in:
Day 1: SystemVerilog
Day 2: Chisel
Day 3: (75% done) Hardcaml

My next days were probably going to be Veryl, Spinal, VHDL, Amaranth, Migen. Maybe I'll get around to it sometime this year!

## Hardcaml
Hardcaml is... hard. The syntax is extremely confusing, even as someone familiar with Chisel through my occupation. Regardless, I saw a lot of similarities, and the built in `tree` circuit builder was extremely helpful for my max finder. 

Arguably the hardest part was figuring out how to set up and compile my first basic circuit. It is very confusing to figure out how to use ocaml and then set up the directories correctly. Instantiation of circuits feels very... fragmented. Of course, with time I imagine it comes like second nature.

Compared to Chisel, another functional language, Hardcaml has less "loosey-goosey" stuff. Although it's nice that it yells at you for every unmatched width and every unused variable, stopping you from compiling, I actually like the ability to have some messiness when I'm building up my circuit at the start. I already know I'm not going to get it right the first time... so why not let me have to option to have a "debug" mode where some of the constraints are relaxed? Chisel (and of course SystemVerilog) definitely is more relaxes in this way, but I would be lying if I said it hadn't bit in the past

## Overall
I used SystemVerilog as my base language, so the top module and a lot of supporting modules are written in this way. Otherwise, I tried to limit whatever coding I did to the language of choice for that AOC day. It was a fun challenge! I wish I had more time to add more polish... Oh well. Maybe my hardcaml attempt is worth 1/2 a t-shirt?

## Dependencies
- yosys
- vivado
- opam
  - hardcaml, ppx_deriving, ppx_deriving_hardcaml, etc
- chisel
- scala-cli

I wish I had more time to give exact versions and instructions to install... otherwise just stumble your way through installations like I did.
