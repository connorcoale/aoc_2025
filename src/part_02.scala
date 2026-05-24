//> using repository https://central.sonatype.com/repository/maven-snapshots
//> using scala 2.13.18
//> using dep org.chipsalliance::chisel:7.12.0
//> using plugin org.chipsalliance:::chisel-plugin:7.12.0
//> using options -unchecked -deprecation -language:reflectiveCalls -feature -Xcheckinit
//> using options -Xfatal-warnings -Ywarn-dead-code -Ywarn-unused -Ymacro-annotations

import scala.io.Source
import chisel3._
// _root_ disambiguates from package chisel3.util.circt if user imports chisel3.util._
import _root_.circt.stage.ChiselStage
import chisel3.util._

class part_02 (num: Int, bcdWidth: Int = 12) extends Module {
  // Need to declare as FlatIO to avoid prefix of io_* for all IO signals.
  val io = FlatIO(new Bundle{
    val cs             = Input(Bool())
    val data           = Input(UInt(8.W))
    val data_valid     = Input(Bool())
    val solution_a     = Output(UInt((4 * bcdWidth).W))
    val solution_b     = Output(UInt((4 * bcdWidth).W))
    val solution_valid = Output(Bool())
  })

  object State extends ChiselEnum {
    val idle, loading, checking, done = Value
  }
  val state     = RegInit(State.idle)
  val stateNext = WireInit(state)
  state         := stateNext

  val doneChecking = WireInit(false.B)
  val enLoad       = WireInit(false.B)
  switch (state) {
    is (State.idle) {
      when (io.data_valid && io.cs) {
        stateNext := State.loading
        enLoad    := true.B
      }
    }
    is (State.loading) {
      enLoad      := (io.data_valid && io.cs)
      when (!(io.data_valid && io.cs)) {
        stateNext := State.checking
      }
    }
    is (State.checking) {
      when (doneChecking) {
        stateNext := State.done
      }
    }
    is (State.done) {
      when (io.data_valid && io.cs) {
        stateNext := State.loading
        enLoad    := true.B
      }
    }
  }

  /////////////////////////////////////////////////////////
  // LOADING LOGIC
  /////////////////////////////////////////////////////////
  // Determine separators for numbers
  val isDash  = io.data === 45.U // "-"
  val isComma = io.data === 44.U // ","
  val isNL    = io.data === 10.U // "\n"

  // Shift in the digits, in ascii-coded-decimal
  val shiftIn = RegInit(0.U.asTypeOf(new BCD(bcdWidth, true)))
  val shiftInShifted = shiftIn.shiftLeft(io.data)
  when (enLoad) {
    when (isDash || isComma) { shiftIn := 0.U.asTypeOf(shiftIn) }
    .otherwise               { shiftIn := shiftInShifted }
  }
  .otherwise                 { shiftIn := 0.U.asTypeOf(shiftIn) }
  val shiftInBCD: BCD  = shiftIn.ascii2dec

  // set up load signals to load all the bcds
  val load_start = Wire(Bool())
  val load_end   = Wire(Bool())
  load_start := isDash
  val firstNL = isNL && !RegNext(isNL)
  load_end   := isComma || firstNL // only store on newline at end of input, not on last line of input as well.
  val starts = Reg(Vec(num, new BCD(bcdWidth)))
  val ends   = Reg(Vec(num, new BCD(bcdWidth)))
  when (load_start) {
    starts(0) := shiftInBCD
    for (i <- 1 until num) {
      starts(i) := starts(i-1)
    }
  }
  when (load_end) {
    ends(0) := shiftInBCD
    for (i <- 1 until num) {
      ends(i) := ends(i-1)
    }
  }

  /////////////////////////////////////////////////////////
  // CHECKING LOGIC
  /////////////////////////////////////////////////////////
  val idChecker = Module(new IDChecker(bcdWidth))
  val check = state === State.checking && !idChecker.io.busy
  when (idChecker.io.done) {
    for (i <- 0 until num - 1) {
      starts(i) := starts(i + 1)
      ends(i)   := ends(i + 1)
    }
    starts(num - 1) := 0.U.asTypeOf(starts(0))
    ends(num - 1)   := 0.U.asTypeOf(ends(0))
  }
  val checkCnt = RegInit(0.U(num.W))
  when (state === State.loading && stateNext === State.checking) { checkCnt := (1.U << (num-1)) }
  .elsewhen (idChecker.io.done)                                  { checkCnt := (checkCnt >> 1) }
  .elsewhen (state === State.checking)                           { checkCnt := (checkCnt) }
  .otherwise                                                     { checkCnt := 0.U }
  doneChecking := (state === State.checking) && !checkCnt.orR


  // Count increases on each "done" of checker
  val cntNext  = Wire(UInt(5.W))
  val cnt      = RegNext(cntNext)
  cntNext      := cnt + idChecker.io.done.asUInt

  val totalA   = Wire(new BCD(bcdWidth))
  val totalB   = Wire(new BCD(bcdWidth))
  val totalInA = totalA
  val totalInB = totalB
  idChecker.io.check    := check
  idChecker.io.start    := starts(0)
  idChecker.io.end      := ends(0)
  idChecker.io.totalInA := totalInA
  idChecker.io.totalInB := totalInB
  totalA                := idChecker.io.totalOutA
  totalB                := idChecker.io.totalOutB

  io.solution_a     := totalA.num.asUInt
  io.solution_b     := totalB.num.asUInt
  io.solution_valid := state === State.done
}

class BCD (val bcdWidth: Int = 10, val isASCII: Boolean = false) extends Bundle {
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

  def dec2ascii: BCD = {
    val bcd = Wire(new BCD(bcdWidth, true))
    bcd.num.zip(num).map{case (ascii, dec) => ascii := 48.U + dec}
    bcd
  }

  def reverse: BCD = {
    val bcd = Wire(new BCD(bcdWidth, isASCII))
    bcd.num.zip(num.reverse).map{case (flipped, unflipped) => flipped := unflipped}
    bcd
  }

  def +(that: BCD): BCD = {
    require(!this.isASCII && !that.isASCII)
    require(this.bcdWidth == that.bcdWidth)
    val sum = Wire(new BCD(bcdWidth))
    // carry between digits
    val carry = Wire(Vec(bcdWidth + 1, Bool()))
    carry(0) := false.B
    for (i <- 0 until bcdWidth) {
      // max rawSum = 9 + 9 + 1 = 19 => need 5 bits. use +&
      val rawSum = this.num(i) +& that.num(i) + carry(i)
      // BCD correction
      val needsAdjust = rawSum > 9.U
      sum.num(i) := Mux(needsAdjust, rawSum - 10.U, rawSum)
      carry(i + 1) := needsAdjust
    }
    sum
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
    val check     = Input(Bool())
    val start     = Input(new BCD(bcdWidth))
    val end       = Input(new BCD(bcdWidth))
    val totalInA  = Input(new BCD(bcdWidth))
    val totalInB  = Input(new BCD(bcdWidth))
    val done      = Output(Bool())
    val busy      = Output(Bool())
    val totalOutA = Output(new BCD(bcdWidth))
    val totalOutB = Output(new BCD(bcdWidth))
  })

  // Check if a BCD of any length has a repeating pattern of any width. Optionally
  // only return invalid when the pattern exists only twice. Accounts for leading zeros.
  def isIDInvalid(id: BCD, patternWidth: Int): (Bool, Bool) = {

    // Determine number of patterns to check, but need to handle cases where 
    // patternWidth doesn't divide evenly into bcdWidth
    val nPatterns = (id.bcdWidth + patternWidth - 1) / patternWidth
    val patterns  = Wire(Vec(nPatterns, Vec(patternWidth, UInt(id.digWidth))))

    // Build pattern vectors (handle padding with zeros for top one)
    for (i <- 0 until nPatterns) {
      for (j <- 0 until patternWidth) {
        val idx = i * patternWidth + j
        if (idx < id.bcdWidth) { patterns(i)(j) := id.num(idx) } 
        else { patterns(i)(j) := 0.U }
      }
    }
    // Reference pattern (should match this if invalid)
    val ref = patterns(0)
    val refHasNoLeading0 = ref(patternWidth-1) =/= 0.U

    // Vector of bits to indicate which patterns have non-zero values
    val patternNonZero = patterns.map { p => p.map(_.orR).reduce(_ || _) }
    val hasAny = patternNonZero.reduce(_ || _)

    // Find highest non-zero pattern which is followed exclusively by all-zero patterns.
    val highestIdx = Mux(hasAny, (nPatterns - 1).U - PriorityEncoder(patternNonZero.reverse), 0.U)

    // Check matching rules
    val matches = VecInit((0 until nPatterns).map { i =>
      Mux(
        i.U > highestIdx,   // are we above the last non-zero pattern?
        true.B,             // if yes, consider it a match
        patterns(i) === ref // if no, check if it matches ref
      )
    })

    val allMatch           = (matches.reduce(_ && _) && refHasNoLeading0 && highestIdx > 0.U)
    val allMatchOnlyDouble = allMatch && (highestIdx === 1.U)

    (allMatchOnlyDouble, allMatch)
  }

  object State extends ChiselEnum {
    val idle, checking = Value
  }

  val state         = RegInit(State.idle)
  val stateNext     = WireInit(State.idle)
  val idNext        = Wire(new BCD(bcdWidth))
  val id            = RegNext(idNext)
  val runningTotalA = Reg(new BCD(bcdWidth))
  val runningTotalB = Reg(new BCD(bcdWidth))
  io.done           := WireInit(false.B)
  state             := stateNext

  val patternWidths = 1 to (bcdWidth / 2) by 1
  val (partAInvalid, partBInvalid) = patternWidths.map(i => isIDInvalid(id, i))
    .unzip match {
      case (a, b) => (a.reduce(_ || _), b.reduce(_ || _))
    }

  val atEnd = id === io.end
  switch (state) {
    is (State.idle) {
      when (io.check) {
        stateNext := State.checking
      }
    }
    is (State.checking) {
      when (atEnd) {
        io.done   := true.B
      } .otherwise {
        stateNext := State.checking
      }
    }
  }

  val loadId = io.check && !RegNext(io.check)

  when (loadId) {
    idNext := io.start
    runningTotalA := io.totalInA
    runningTotalB := io.totalInB
  } .elsewhen (state === State.checking) {
    idNext := id.++
    when (partAInvalid) { runningTotalA := runningTotalA + id }
    when (partBInvalid) { runningTotalB := runningTotalB + id }
  } .otherwise {
    idNext := 0.U.asTypeOf(idNext)
  }

  io.totalOutA := runningTotalA
  io.totalOutB := runningTotalB
  io.busy      := state === State.checking
}

object Main extends App {

  def countDashes(path: String): Int = {
    val src = Source.fromFile(path)
    try {
      src.mkString.count(_ == '-')
    } finally {
      src.close()
    }
  }
  println(
    ChiselStage.emitSystemVerilog(
      gen = new part_02(countDashes("sim/stimulus/02/input_02.txt")),
      firtoolOpts = Array("-o", "src/part_02.sv",
                          "-disable-all-randomization",
                          "-strip-debug-info",
                          "-default-layer-specialization=enable",
                          "--lowering-options=disallowLocalVariables"
                         )
    )
  )
}
