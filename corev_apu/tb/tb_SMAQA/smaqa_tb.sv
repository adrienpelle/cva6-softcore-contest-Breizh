`timescale 1ns / 1ps


module smaqa_tb
  import ariane_pkg::*;
  # (parameter config_pkg::cva6_cfg_t CVA6Cfg = cva6_config_pkg::cva6_cfg);

// CVA6 configuration: This part could be found in cva6.sv
// We use config cva6_cfg in file ima_sv32_fpga_config_pkg.sv
// ---------------------------------------------------------------------------------------------------------------------------------------
  // Extended config
  localparam bit RVF = (riscv::IS_XLEN64 | riscv::IS_XLEN32) & CVA6Cfg.FpuEn;
  localparam bit RVD = (riscv::IS_XLEN64 ? 1 : 0) & CVA6Cfg.FpuEn;
  localparam bit FpPresent = RVF | RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;
  localparam bit NSX = CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8 | CVA6Cfg.XFVec;  // Are non-standard extensions present?
  localparam int unsigned FLen = RVD ? 64 :  // D ext.
  RVF ? 32 :  // F ext.
  CVA6Cfg.XF16 ? 16 :  // Xf16 ext.
  CVA6Cfg.XF16ALT ? 16 :  // Xf16alt ext.
  CVA6Cfg.XF8 ? 8 :  // Xf8 ext.
  1;  // Unused in case of no FP

  // Transprecision floating-point extensions configuration
  localparam bit RVFVec     = RVF             & CVA6Cfg.XFVec & FLen>32; // FP32 vectors available if vectors and larger fmt enabled
  localparam bit XF16Vec    = CVA6Cfg.XF16    & CVA6Cfg.XFVec & FLen>16; // FP16 vectors available if vectors and larger fmt enabled
  localparam bit XF16ALTVec = CVA6Cfg.XF16ALT & CVA6Cfg.XFVec & FLen>16; // FP16ALT vectors available if vectors and larger fmt enabled
  localparam bit XF8Vec     = CVA6Cfg.XF8     & CVA6Cfg.XFVec & FLen>8;  // FP8 vectors available if vectors and larger fmt enabled

  localparam bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
  localparam int unsigned NrWbPorts = (CVA6Cfg.CvxifEn || EnableAccelerator) ? 5 : 4;

// ##############################################################
//#                                                             #
            localparam NrRgprPorts = 3; // 3 reading ports      #
//#                                                             #
// ##############################################################

  localparam config_pkg::cva6_cfg_t CVA6ExtendCfg = {
    CVA6Cfg.NrCommitPorts,
    CVA6Cfg.AxiAddrWidth,
    CVA6Cfg.AxiDataWidth,
    CVA6Cfg.AxiIdWidth,
    CVA6Cfg.AxiUserWidth,
    CVA6Cfg.NrLoadBufEntries,
    CVA6Cfg.FpuEn,
    CVA6Cfg.XF16,
    CVA6Cfg.XF16ALT,
    CVA6Cfg.XF8,
    CVA6Cfg.RVA,
    CVA6Cfg.RVV,
    CVA6Cfg.RVC,
    CVA6Cfg.RVZCB,
    CVA6Cfg.XFVec,
    CVA6Cfg.CvxifEn,
    CVA6Cfg.ZiCondExtEn,
    // Extended
    bit'(RVF),
    bit'(RVD),
    bit'(FpPresent),
    bit'(NSX),
    unsigned'(FLen),
    bit'(RVFVec),
    bit'(XF16Vec),
    bit'(XF16ALTVec),
    bit'(XF8Vec),
    unsigned'(NrRgprPorts),
    unsigned'(NrWbPorts),
    bit'(EnableAccelerator),
    CVA6Cfg.HaltAddress,
    CVA6Cfg.ExceptionAddress,
    CVA6Cfg.RASDepth,
    CVA6Cfg.BTBEntries,
    CVA6Cfg.BHTEntries,
    CVA6Cfg.DmBaseAddress,
    CVA6Cfg.NrPMPEntries,
    CVA6Cfg.NOCType,
    CVA6Cfg.NrNonIdempotentRules,
    CVA6Cfg.NonIdempotentAddrBase,
    CVA6Cfg.NonIdempotentLength,
    CVA6Cfg.NrExecuteRegionRules,
    CVA6Cfg.ExecuteRegionAddrBase,
    CVA6Cfg.ExecuteRegionLength,
    CVA6Cfg.NrCachedRegionRules,
    CVA6Cfg.CachedRegionAddrBase,
    CVA6Cfg.CachedRegionLength,
    CVA6Cfg.MaxOutstandingStores
  };
// ---------------------------------------------------------------------------------------------------------------------------------------
  
    logic clk_i_tb;
    logic rst_ni_tb;
  
    // wire for multiplier
    logic         [TRANS_ID_BITS-1:0] trans_id_i_tb;
    logic                             mult_valid_i_tb;      // Set 1
    fu_op                             operation_i_tb;       // Set SMAQA
    riscv::xlen_t                     operand_a_i_tb;       // 32 bits data a
    riscv::xlen_t                     operand_b_i_tb;       // 32 bits data b
    riscv::xlen_t                     operand_c_i_tb;       // the third operand for SMAQA
    riscv::xlen_t                     result_o_tb;                   // 32 bits out data
    logic                             mult_valid_o_tb;               // see 1
    logic                             mult_ready_o_tb;               // see 1
    logic         [TRANS_ID_BITS-1:0] mult_trans_id_o_tb;            // equal trans_id_i_tb
  
    // wire for regfile
    // read port
    logic [2:0][4:0]  raddr_i_tb;
    logic [2:0][31:0] rdata_o_tb;
    // write port
    logic [4:0]       waddr_i_tb;
    logic [31:0]      wdata_i_tb;
    logic             we_i_tb;

    // wire for decoder
    logic [31:0] instruction_i_tb;          // 8h'C820_81F7: smaqa: R1 + R2 -> R3
   // Outputs
    scoreboard_entry_t instruction_o_tb;    // concern fu (MULT), op (SMAQA), rs1 (0001), rs2 (0010) and rd (0011)
    logic is_control_flow_instr_o_tb;   
    
    multiplier #(
    .CVA6Cfg(CVA6ExtendCfg))
    mutiplier_tb (
    .clk_i(clk_i_tb),
    .rst_ni(rst_ni_tb),
    .trans_id_i(trans_id_i_tb),
    .mult_valid_i(mult_valid_i_tb),
    .operation_i(operation_i_tb),
    .operand_a_i(operand_a_i_tb),
    .operand_b_i(operand_b_i_tb),
    .operand_c_i(operand_c_i_tb),             // the third operand for SMAQA
    .result_o(result_o_tb),
    .mult_valid_o(mult_valid_o_tb),
    .mult_ready_o(mult_ready_o_tb),
    .mult_trans_id_o(mult_trans_id_o_tb)
);

    ariane_regfile_fpga #(
    .CVA6Cfg(CVA6ExtendCfg),
    .NR_READ_PORTS(NrRgprPorts)
    ) 
    regfile_tb (
    // clock and reset
    .clk_i(clk_i_tb),
    .rst_ni(rst_ni_tb),
    // disable clock gates for testing
    .test_en_i(1'b0),                        // Useless
    // read port
    .raddr_i(raddr_i_tb),                    // address 4 bits x 3
    .rdata_o(rdata_o_tb),                           // 32 bits data x 3
    // write port
    .waddr_i(waddr_i_tb),                   // address 4 bits
    .wdata_i(wdata_i_tb),                   // 32 bits data
    .we_i(we_i_tb)                          // Set to 1 to write
);

    decoder #(
    .CVA6Cfg(CVA6ExtendCfg))
    decoder_tb (
    .debug_req_i(1'b0),                                   // be not used. set 0
    .pc_i(32'h00000000),                                  // be not use
    .is_compressed_i(1'b0),                               // be not use
    .compressed_instr_i(16'h0000),                        // be not use
    .is_illegal_i(1'b0),                                  // be not use
    .instruction_i(instruction_i_tb),                        // 32 bits instruction
    .branch_predict_i('0),                                // be not use
    .ex_i('0),                                            // be not use
    .irq_i(2'b00),                                        // be not use
    .irq_ctrl_i('0),                                      // be not use
    .priv_lvl_i(riscv::PRIV_LVL_U),                       // be not use
    .debug_mode_i(1'b0),                                  // be not use
    .fs_i(riscv::Off),                                    // be not use
    .frm_i(3'b000),                                       // be not use
    .vs_i(riscv::Off),                                    // be not use
    .tvm_i(1'b0),                                         // be not use
    .tw_i(1'b0),                                          // be not use
    .tsr_i(1'b0),                                         // be not use
    .instruction_o(instruction_o_tb),                             // output instruction
    .is_control_flow_instr_o(is_control_flow_instr_o_tb)          // should be 1'b0 or 1'b1
  );

    // Connection of 3 blocks
    assign operation_i_tb = instruction_o_tb.op;
    assign operand_a_i_tb = rdata_o_tb[0];
    assign operand_b_i_tb = rdata_o_tb[1];
    assign operand_c_i_tb = rdata_o_tb[2];
    
    assign raddr_i_tb[0]  = instruction_o_tb.rs1;
    assign raddr_i_tb[1]  = instruction_o_tb.rs2;
    assign raddr_i_tb[2]  = instruction_o_tb.rd;

// Clock generator T=100ns -> f = 10Mhz
always begin
    #50 clk_i_tb = ~clk_i_tb;  // Toggle the clock every 5 time units
end

initial begin

    clk_i_tb = 0;        
    rst_ni_tb = 0;       
    #200;                
    rst_ni_tb = 1;             // Release reset after some time
    we_i_tb   = 1;             // enable write
    mult_valid_i_tb = 1;
    
    #100;                      // clk H->L
    // write port
    waddr_i_tb = 4'b0001;      // R1      
    wdata_i_tb = 32'h01020304;
    
    #100;                      // clk H->L
    // write port
    waddr_i_tb = 4'b0010;      // R2      
    wdata_i_tb = 32'h05060708;
    
    #100;                      // clk H->L
    // write port
    waddr_i_tb = 4'b0011;      // R3      
    wdata_i_tb = 32'h00000009; // Expect -> 32'h 0000004F = 1x5 + 2x6 + 3x7 + 4x8 + 9
    
    #100;                              // clk H->L
    we_i_tb   = 0;                     // enable read (turn off write)    
    instruction_i_tb = 32'hC820_81F7;   // smaqa: R1 + R2 -> R3
    
    #20;
    if(instruction_o_tb.op == ariane_pkg::SMAQA) begin
        $display("Pass Decoder SMAQA.");
    end else begin
        $display("Fail Decoder SMAQA.");
    end

    
    #100;                                                  // The regfile launches the operands here
    if(operand_c_i_tb == 32'h00000009) begin
        $display("Pass Register files SMAQA.");
    end else begin
        $display("Fail Register files SMAQA.");
    end
    
    #100;                                                  // The output launch here
    if(result_o_tb == 32'h0000004F) begin
        $display("Pass Multiplier SMAQA.");
    end else begin
        $display("Fail PassMultiplier SMAQA.");
    end   
        
end



endmodule
