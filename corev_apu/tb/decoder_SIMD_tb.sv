`timescale 1ns / 1ps

module decoder_tb
  import ariane_pkg::*;();
  // Inputs
  logic debug_req_i;
  logic [31:0] pc_i;
  logic is_compressed_i;
  logic [15:0] compressed_instr_i;
  logic is_illegal_i;
  logic [31:0] instruction_i;
  logic [1:0] irq_i;
  logic [31:0] branch_predict_i;
  logic [31:0] ex_i;
  logic [31:0] irq_ctrl_i;
  logic [2:0] priv_lvl_i;
  logic debug_mode_i;
  logic [2:0] fs_i;
  logic [2:0] frm_i;
  logic [2:0] vs_i;
  logic tvm_i;
  logic tw_i;
  logic tsr_i;

  // Outputs
  scoreboard_entry_t instruction_o;
  logic is_control_flow_instr_o;

  // Instantiate the Unit Under Test (UUT)
  decoder uut (
    .debug_req_i(debug_req_i),
    .pc_i(pc_i),
    .is_compressed_i(is_compressed_i),
    .compressed_instr_i(compressed_instr_i),
    .is_illegal_i(is_illegal_i),
    .instruction_i(instruction_i),
    .branch_predict_i(branch_predict_i),
    .ex_i(ex_i),
    .irq_i(irq_i),
    .irq_ctrl_i(irq_ctrl_i),
    .priv_lvl_i(priv_lvl_i),
    .debug_mode_i(debug_mode_i),
    .fs_i(fs_i),
    .frm_i(frm_i),
    .vs_i(vs_i),
    .tvm_i(tvm_i),
    .tw_i(tw_i),
    .tsr_i(tsr_i),
    .instruction_o(instruction_o),
    .is_control_flow_instr_o(is_control_flow_instr_o)
    // Note: Add other signals if your module has more outputs
  );

  initial begin
    // Initialize Inputs
    debug_req_i = 0;
    pc_i = 32'h0000_0000;
    is_compressed_i = 0;
    compressed_instr_i = 16'h0000;
    irq_i = 2'b00;
    branch_predict_i = 32'b0;
    ex_i = 32'b0;
    irq_ctrl_i = 32'b0;
    priv_lvl_i = 3'b0;
    debug_mode_i = 0;
    fs_i = 3'b0;
    frm_i = 3'b0;
    vs_i = 3'b0;
    tvm_i = 0;
    tw_i = 0;
    tsr_i = 0;

    #10; instruction_i = 32'h4011_01F7; // Test ADD16 
    #10; if(instruction_o.op == ariane_pkg::ADD16) begin
        $display("Pass ADD16");
    end else begin
        $display("Fail ADD16");
    end
    
    #10; instruction_i = 32'h4211_01F7; // Test SUB16 
    #10; if(instruction_o.op == ariane_pkg::SUB16) begin
        $display("Pass SUB16");
    end else begin
        $display("Fail SUB16");
    end    

    #10; instruction_i = 32'h4811_01F7; // Test ADD8
    #10; if(instruction_o.op == ariane_pkg::ADD8) begin
        $display("Pass ADD8");
    end else begin
        $display("Fail ADD8");
    end
    
    #10; instruction_i = 32'h4A11_01F7; // Test SUB8
    #10; if(instruction_o.op == ariane_pkg::SUB8) begin
        $display("Pass SUB8");
    end else begin
        $display("Fail SUB8");
    end
    
    #10; instruction_i = 32'h0811_01F7; // Test RADD8
    #10; if(instruction_o.op == ariane_pkg::RADD8) begin
        $display("Pass RADD8");
    end else begin
        $display("Fail RADD8");
    end
    
    #10; instruction_i = 32'h0A11_01F7; // Test RSUB8
    #10; if(instruction_o.op == ariane_pkg::RSUB8) begin
        $display("Pass RSUB8");
    end else begin
        $display("Fail RSUB8");
    end
    
    #10; instruction_i = 32'h0110_01F7; // Test RADD16
    #10; if(instruction_o.op == ariane_pkg::RADD16) begin
        $display("Pass RADD16");
    end else begin
        $display("Fail RADD16");
    end
    
    #10; instruction_i = 32'h0211_01F7; // Test RSUB16
    #10; if(instruction_o.op == ariane_pkg::RSUB16) begin
        $display("Pass RSUB16");
    end else begin
        $display("Fail RSUB16");
    end
    
    #10; instruction_i = 32'h0211_01F7; // Test URADD8
    #10; if(instruction_o.op == ariane_pkg::URADD8) begin
        $display("Pass URADD8");
    end else begin
        $display("Fail URADD8");
    end
    
    #10; instruction_i = 32'h2811_01F7; // Test URSUB8
    #10; if(instruction_o.op == ariane_pkg::URSUB8) begin
        $display("Pass URSUB8");
    end else begin
        $display("Fail URSUB8");
    end
    
    #10; instruction_i = 32'h2A11_01F7; // Test URADD16
    #10; if(instruction_o.op == ariane_pkg::URADD16) begin
        $display("Pass URADD16");
    end else begin
        $display("Fail URADD16");
    end
    
    #10; instruction_i = 32'h2011_01F7; // Test URSUB16
    #10; if(instruction_o.op == ariane_pkg::URSUB16) begin
        $display("Pass URSUB16");
    end else begin
        $display("Fail URSUB16");
    end

    #10; instruction_i = 32'h0811_01F7; // Test KADD16
    #10; if(instruction_o.op == ariane_pkg::KADD16) begin
        $display("Pass KADD16");
    end else begin
        $display("Fail KADD16");
    end
    
    #10; instruction_i = 32'h2811_01F7; // Test UKADD16
    #10; if(instruction_o.op == ariane_pkg::UKADD16) begin
        $display("Pass UKADD16");
    end else begin
        $display("Fail UKADD16");
    end
    
    #10; instruction_i = 32'h0A11_01F7; // Test KSUB16
    #10; if(instruction_o.op == ariane_pkg::KSUB16) begin
        $display("Pass KSUB16");
    end else begin
        $display("Fail KSUB16");
    end
    
    #10; instruction_i = 32'h2A11_01F7; // Test UKSUB16
    #10; if(instruction_o.op == ariane_pkg::UKSUB16) begin
        $display("Pass UKSUB16");
    end else begin
        $display("Fail UKSUB16");
    end
    
    #10; instruction_i = 32'h0C11_01F7; // Test KADD8
    #10; if(instruction_o.op == ariane_pkg::KADD8) begin
        $display("Pass KADD8");
    end else begin
        $display("Fail KADD8");
    end
    
    #10; instruction_i = 32'h2C11_01F7; // Test UKADD8
    #10; if(instruction_o.op == ariane_pkg::UKADD8) begin
        $display("Pass UKADD8");
    end else begin
        $display("Fail UKADD8");
    end
    
    #10; instruction_i = 32'h0E11_01F7; // Test KSUB8
    #10; if(instruction_o.op == ariane_pkg::KSUB8) begin
        $display("Pass KSUB8");
    end else begin
        $display("Fail KSUB8");
    end
    
    #10; instruction_i = 32'h2E11_01F7; // Test UKSUB8
    #10; if(instruction_o.op == ariane_pkg::UKSUB8) begin
        $display("Pass UKSUB8");
    end else begin
        $display("Fail UKSUB8");
    end
    
    #10; instruction_i = 32'h4811_01F7; // Test CRAS16
    #10; if(instruction_o.op == ariane_pkg::CRAS16) begin
        $display("Pass CRAS16");
    end else begin
        $display("Fail CRAS16");
    end
    
    #10; instruction_i = 32'h0211_01F7; // Test RCRAS16
    #10; if(instruction_o.op == ariane_pkg::RCRAS16) begin
        $display("Pass RCRAS16");
    end else begin
        $display("Fail RCRAS16");
    end
    
    #10; instruction_i = 32'h2211_01F7; // Test URCRAS16
    #10; if(instruction_o.op == ariane_pkg::URCRAS16) begin
        $display("Pass URCRAS16");
    end else begin
        $display("Fail URCRAS16");
    end
    
    #10; instruction_i = 32'h0A11_01F7; // Test KCRAS16
    #10; if(instruction_o.op == ariane_pkg::KCRAS16) begin
        $display("Pass KCRAS16");
    end else begin
        $display("Fail KCRAS16");
    end
    
    #10; instruction_i = 32'h2A11_01F7; // Test UKCRAS16
    #10; if(instruction_o.op == ariane_pkg::UKCRAS16) begin
        $display("Pass UKCRAS16");
    end else begin
        $display("Fail UKCRAS16");
    end
    
    #10; instruction_i = 32'h4A11_01F7; // Test CRSA16
    #10; if(instruction_o.op == ariane_pkg::CRSA16) begin
        $display("Pass CRSA16");
    end else begin
        $display("Fail CRSA16");
    end
    
    #10; instruction_i = 32'h0611_01F7; // Test RCRSA16
    #10; if(instruction_o.op == ariane_pkg::RCRSA16) begin
        $display("Pass RCRSA16");
    end else begin
        $display("Fail RCRSA16");
    end
    
    #10; instruction_i = 32'h2611_01F7; // Test URCRSA16
    #10; if(instruction_o.op == ariane_pkg::URCRSA16) begin
        $display("Pass URCRSA16");
    end else begin
        $display("Fail URCRSA16");
    end
    
    #10; instruction_i = 32'h0B11_01F7; // Test KCRSA16
    #10; if(instruction_o.op == ariane_pkg::KCRSA16) begin
        $display("Pass KCRSA16");
    end else begin
        $display("Fail KCRSA16");
    end
    
    #10; instruction_i = 32'h2B11_01F7; // Test UKCRSA16
    #10; if(instruction_o.op == ariane_pkg::UKCRSA16) begin
        $display("Pass UKCRSA16");
    end else begin
        $display("Fail UKCRSA16");
    end
    
    #10; instruction_i = 32'hF451_01F7; // Test STAS16
    #10; if(instruction_o.op == ariane_pkg::STAS16) begin
        $display("Pass STAS16");
    end else begin
        $display("Fail STAS16");
    end
    
    #10; instruction_i = 32'hB451_01F7; // Test RSTAS16
    #10; if(instruction_o.op == ariane_pkg::RSTAS16) begin
        $display("Pass RSTAS16");
    end else begin
        $display("Fail RSTAS16");
    end
    
    #10; instruction_i = 32'hD451_01F7; // Test URSTAS16
    #10; if(instruction_o.op == ariane_pkg::URSTAS16) begin
        $display("Pass URSTAS16");
    end else begin
        $display("Fail URSTAS16");
    end
    
    #10; instruction_i = 32'hC451_01F7; // Test KSTAS16
    #10; if(instruction_o.op == ariane_pkg::KSTAS16) begin
        $display("Pass KSTAS16");
    end else begin
        $display("Fail KSTAS16");
    end
    
    #10; instruction_i = 32'hE451_01F7; // Test UKSTAS16
    #10; if(instruction_o.op == ariane_pkg::UKSTAS16) begin
        $display("Pass UKSTAS16");
    end else begin
        $display("Fail UKSTAS16");
    end
    
    #10; instruction_i = 32'hF651_01F7; // Test STSA16
    #10; if(instruction_o.op == ariane_pkg::STSA16) begin
        $display("Pass STSA16");
    end else begin
        $display("Fail STSA16");
    end
    
    #10; instruction_i = 32'hB651_01F7; // Test RSTSA16
    #10; if(instruction_o.op == ariane_pkg::RSTSA16) begin
        $display("Pass RSTSA16");
    end else begin
        $display("Fail RSTSA16");
    end
    
    #10; instruction_i = 32'hD651_01F7; // Test URSTSA16
    #10; if(instruction_o.op == ariane_pkg::URSTSA16) begin
        $display("Pass URSTSA16");
    end else begin
        $display("Fail URSTSA16");
    end
    
    #10; instruction_i = 32'hC651_01F7; // Test KSTSA16
    #10; if(instruction_o.op == ariane_pkg::KSTSA16) begin
        $display("Pass KSTSA16");
    end else begin
        $display("Fail KSTSA16");
    end
    
    #10; instruction_i = 32'hE651_01F7; // Test UKSTSA16
    #10; if(instruction_o.op == ariane_pkg::UKSTSA16) begin
        $display("Pass UKSTSA16");
    end else begin
        $display("Fail UKSTSA16");
    end

//    #10;

    $finish;
  end

endmodule
