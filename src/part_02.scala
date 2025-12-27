//> using repository https://central.sonatype.com/repository/maven-snapshots
//> using scala 2.13.18
//> using dep org.chipsalliance::chisel:7.6.0
//> using plugin org.chipsalliance:::chisel-plugin:7.6.0
//> using options -unchecked -deprecation -language:reflectiveCalls -feature -Xcheckinit
//> using options -Xfatal-warnings -Ywarn-dead-code -Ywarn-unused -Ymacro-annotations

import chisel3._
// _root_ disambiguates from package chisel3.util.circt if user imports chisel3.util._
import _root_.circt.stage.ChiselStage
import chisel3.util.{RegEnable}

class part_02 extends Module {
  // Need to declare as FlatIO to avoid prefix of io_* for all IO signals.
  val io = FlatIO(new Bundle{
    val cs             = Input(Bool())
    val data           = Input(UInt(8.W))
    val data_valid     = Input(Bool())
    val solution_a     = Output(UInt(80.W)) // change to 80 for now
    val solution_b     = Output(UInt(80.W)) // change to 80 for now
    val solution_valid = Output(Bool())
  })


  val shiftIn = RegInit(VecInit(Seq.fill(10)(0.U(8.W))))
  val shiftInShifted = VecInit(shiftIn.tail :+ io.data)
  when (io.data_valid) {
    for (i <- 0 to 9 by 1) {
      shiftIn(i) := shiftInShifted(i)
    }
  }

  // val isDigit = 48.U <= io.data && io.data <= 57.U
  val nextDigs = VecInit(shiftIn.reverse.map(dig => dig(3,0)))
  val isDash  = io.data === 54.U // "-"
  val isComma = io.data === 44.U // ","
  val start      = RegEnable(nextDigs, isDash)
  val end        = RegEnable(nextDigs, isComma)
  dontTouch(start)
  dontTouch(end)

  io.solution_a := shiftIn.asUInt
  io.solution_b := shiftInShifted.asUInt
  io.solution_valid := 0.B


}


object Main extends App {
  println(
    ChiselStage.emitSystemVerilog(
      gen = new part_02,
      firtoolOpts = Array("-disable-all-randomization", "-strip-debug-info", "-default-layer-specialization=enable")
    )
  )
}
