//> using repository https://central.sonatype.com/repository/maven-snapshots
//> using scala 2.13.18
//> using dep org.chipsalliance::chisel:7.6.0
//> using plugin org.chipsalliance:::chisel-plugin:7.6.0
//> using options -unchecked -deprecation -language:reflectiveCalls -feature -Xcheckinit
//> using options -Xfatal-warnings -Ywarn-dead-code -Ywarn-unused -Ymacro-annotations

import chisel3._
// _root_ disambiguates from package chisel3.util.circt if user imports chisel3.util._
import _root_.circt.stage.ChiselStage
import chisel3.util._

class part_02 (num: Int) extends Module {
  // Need to declare as FlatIO to avoid prefix of io_* for all IO signals.
  val io = FlatIO(new Bundle{
    val cs             = Input(Bool())
    val data           = Input(UInt(8.W))
    val data_valid     = Input(Bool())
    val solution_a     = Output(UInt(80.W)) // change to 80 for now
    val solution_b     = Output(UInt(80.W)) // change to 80 for now
    val solution_valid = Output(Bool())
  })

  // Determine separators for numbers
  val isDash  = io.data === 45.U // "-"
  val isComma = io.data === 44.U // ","

  // Shift in the digits, in ascii-coded-decimal
  val shiftIn = RegInit(0.U.asTypeOf(new BCD(10, true)))
  val shiftInShifted = shiftIn.shiftLeft(io.data)
  when (io.data_valid && io.cs) {
    when (isDash || isComma) { shiftIn := 0.U.asTypeOf(shiftIn) }
    .otherwise               { shiftIn := shiftInShifted }
  } .elsewhen(io.cs)         { shiftIn := 0.U.asTypeOf(shiftIn) }
  val shiftInBCD: BCD  = shiftIn.ascii2dec

  // Count increases on every comma
  val cntNext  = Wire(UInt(5.W))
  val cnt      = RegNext(cntNext)
  cntNext      := cnt + isComma.asUInt

  // set up load signals to load all the bcds
  val load_start = Wire(Vec(num, Bool()))
  val load_end   = Wire(Vec(num, Bool()))
  for (i <- 0 to (num-1) by 1) {
    load_start(i) := cnt === i.U && isDash
    load_end(i)   := cnt === i.U && isComma
  }
  dontTouch(load_start)
  dontTouch(load_end)
  val starts = VecInit(Seq.tabulate(num) {i => RegEnable(shiftInBCD, load_start(i))})
  val ends   = VecInit(Seq.tabulate(num) {i => RegEnable(shiftInBCD, load_end(i))})

  val check = !io.data_valid && RegNext(io.data_valid)
  val done  = Wire(Bool())
  val total = Wire(new BCD(10))
  val totalIn = RegNext(total)
  val idChecker = Module(new IDChecker(10))
  idChecker.io.check   := check
  idChecker.io.start   := starts(0)
  idChecker.io.end     := ends(0)
  idChecker.io.totalIn := totalIn
  done                 := idChecker.io.done
  total                := idChecker.io.totalOut
  io.solution_a := shiftIn.num.asUInt
  io.solution_b := shiftInShifted.num.asUInt
  io.solution_valid := 0.B

}

class BCD (val bcdWidth: Int = 10, isASCII: Boolean = false) extends Bundle {
  val digWidth = if (isASCII) 8.W else 4.W
  val num = Vec(bcdWidth, UInt(digWidth))

  def shiftLeft(data: UInt): BCD = {
    val bcd = Wire(new BCD(bcdWidth, isASCII))
    for (i <- 0 to bcdWidth-1 by 1) {
      if (i == 0) bcd.num(i) := data
      else bcd.num(i) := num(i-1)
    }
    bcd
  }

  def ascii2dec: BCD = {
    val bcd = Wire(new BCD(bcdWidth))
    bcd.num.zip(num).map{case (dec, ascii) => dec := ascii(3, 0)}
    bcd
  }

  def reverse: BCD = {
    val bcd = Wire(new BCD(bcdWidth, isASCII))
    bcd.num.zip(num.reverse).map{case (flipped, unflipped) => flipped := unflipped}
    bcd
  }

  def ++ : BCD = {
    require(!isASCII)
    val bcdAdded = Wire(new BCD(bcdWidth))
    for (i <- 0 to bcdWidth-1 by 1) {
      if (i == 0) bcdAdded.num(i) := num(i) + 1.U
      else        bcdAdded.num(i) := num(i) + (bcdAdded.num(i-1) === 10.U).asUInt
    }
    val bcd = Wire(new BCD(bcdWidth))
    for (i <- 0 to bcdWidth-1 by 1) {
      bcd.num(i) := Mux(bcdAdded.num(i) === 10.U, 0.U, bcdAdded.num(i))
    }
    bcd
  }
  
  def ===(that: BCD): Bool = {
    require(this.bcdWidth == that.bcdWidth)
    this.num.zip(that.num).map { case (a, b) => a === b }.reduce(_ && _)
  }
}

class IDChecker (bcdWidth: Int) extends Module {
  val io = IO (new Bundle{
    val check    = Input(Bool())
    val start    = Input(new BCD(bcdWidth))
    val end      = Input(new BCD(bcdWidth))
    val totalIn  = Input(new BCD(bcdWidth))
    val done     = Output(Bool())
    val totalOut = Output(new BCD(bcdWidth))
  })

  // Check if a BCD of any length has a repeating pattern of any width. Optionally
  // only return invalid when the pattern exists only twice. Accounts for leading zeros.
  def isIDValid(id: BCD, patternWidth: Int, onlyDouble: Boolean): Bool = {
    // Need to handle cases where patternWidth doesn't divide evenly.
    val nPatterns = (id.bcdWidth + patternWidth - 1) / patternWidth
    val patterns  = Wire(Vec(nPatterns, Vec(patternWidth, UInt(id.digWidth))))
    // Build patterns (handle padding with zeros for top one)
    for (i <- 0 until nPatterns) {
      for (j <- 0 until patternWidth) {
        val idx = i * patternWidth + j
        if (idx < id.bcdWidth) {
          patterns(i)(j) := id.num(idx)
        } else {
          patterns(i)(j) := 0.U
        }
      }
    }
    // Vector of bits to indicate which patterns have values
    val patternNonZero = patterns.map { p => p.map(_.orR).reduce(_ || _) }
    val hasAny = patternNonZero.reduce(_ || _)
    // Find highest non-zero pattern
    val highestIdx = Mux(hasAny, (nPatterns - 1).U - PriorityEncoder(patternNonZero.reverse), 0.U)
    // Reference pattern (should match this)
    val ref = patterns(0)
    // Check matching rules
    val matches = VecInit((0 until nPatterns).map { i =>
      Mux(
        i.U > highestIdx,   // location of first all-zero candidate followed exclusively by all-zero candidates
        true.B,             // ignore ONLY leading-zero patterns (say it's "matching" by default for when above last non-zero candidate)
        patterns(i) === ref // check if candidate is equal when below last non-zero candidate
      )
    })
    // If we only want to count doubled IDs, add this extra check
    val evalOnlyDouble = !onlyDouble.B || (highestIdx === 1.U)
    !(hasAny && matches.reduce(_ && _) && highestIdx > 0.U && evalOnlyDouble)
  }

  object State extends ChiselEnum {
    val idle, checking = Value
  }

  val state     = RegInit(State.idle)
  val stateNext = WireInit(State.idle)
  val idNext    = Wire(new BCD(bcdWidth))
  val id        = RegNext(idNext)
  io.done       := WireInit(false.B)
  state         := stateNext
  dontTouch(state)

  switch (state) {
    is (State.idle) {
      when (io.check) {
        stateNext := State.checking
      }
    }
    is (State.checking) {
      when (id === io.end) {
        io.done   := true.B
      } .otherwise {
        stateNext := State.checking
      }
    }
  }


  val loadId = io.check && !RegNext(io.check)
  dontTouch(loadId)

  when (loadId) {
    idNext := io.start
  } .elsewhen (state === State.checking) {
    idNext := id.++
  } .otherwise {
    idNext := 0.U.asTypeOf(idNext)
  }
  dontTouch(id)
  val invalid2 = isIDValid(id, 2, true)
  dontTouch(invalid2)
  val invalid3 = isIDValid(id, 3, true)
  dontTouch(invalid3)
  val invalid4 = isIDValid(id, 4, true)
  dontTouch(invalid4)
  val invalid5 = isIDValid(id, 5, true)
  dontTouch(invalid5)

  io.totalOut := 0.U.asTypeOf(io.totalOut)
}

object Main extends App {
  println(
    ChiselStage.emitSystemVerilog(
      gen = new part_02(10),
      firtoolOpts = Array("-disable-all-randomization", "-strip-debug-info", "-default-layer-specialization=enable")
    )
  )
}
