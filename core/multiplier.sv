// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
//
// Description: Multiplication Unit with one pipeline register
//              This unit relies on retiming features of the synthesizer
//


module multiplier
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input  logic                             clk_i,
    input  logic                             rst_ni,
    input  logic         [TRANS_ID_BITS-1:0] trans_id_i,
    input  logic                             mult_valid_i,
    input  fu_op                             operation_i,
    input  riscv::xlen_t                     operand_a_i,
    input  riscv::xlen_t                     operand_b_i,
    input  riscv::xlen_t                     operand_c_i,       // the third operand for SMAQA
    input  riscv::xlen_t                     operand_d_i,       // fourth operand for SMAQA64 (rs1 + 1)
    input  riscv::xlen_t                     operand_e_i,       // fifth operand for SMAQA64 (rs2 + 1)
    output riscv::xlen_t                     result_o,
    output logic                             mult_valid_o,
    output logic                             mult_ready_o,
    output logic         [TRANS_ID_BITS-1:0] mult_trans_id_o
);
  // Carry-less multiplication
  logic [riscv::XLEN-1:0]
      clmul_q, clmul_d, clmulr_q, clmulr_d, operand_a, operand_b, operand_a_rev, operand_b_rev;
  logic clmul_rmode, clmul_hmode;

  if (ariane_pkg::BITMANIP) begin : gen_bitmanip
    // checking for clmul_rmode and clmul_hmode
    assign clmul_rmode = (operation_i == CLMULR);
    assign clmul_hmode = (operation_i == CLMULH);

    // operand_a and b reverse generator
    for (genvar i = 0; i < riscv::XLEN; i++) begin
      assign operand_a_rev[i] = operand_a_i[(riscv::XLEN-1)-i];
      assign operand_b_rev[i] = operand_b_i[(riscv::XLEN-1)-i];
    end

    // operand_a and operand_b selection
    assign operand_a = (clmul_rmode | clmul_hmode) ? operand_a_rev : operand_a_i;
    assign operand_b = (clmul_rmode | clmul_hmode) ? operand_b_rev : operand_b_i;

    // implementation
    always_comb begin
      clmul_d = '0;
      for (int i = 0; i <= riscv::XLEN; i++) begin
        clmul_d = (|((operand_b >> i) & 1)) ? clmul_d ^ (operand_a << i) : clmul_d;
      end
    end

    // clmulr + clmulh result generator
    for (genvar i = 0; i < riscv::XLEN; i++) begin
      assign clmulr_d[i] = clmul_d[(riscv::XLEN-1)-i];
    end
  end

  // Pipeline register
  logic [TRANS_ID_BITS-1:0] trans_id_q;
  logic                     mult_valid_q;
  fu_op operator_d, operator_q;
  logic [riscv::XLEN*2-1:0] mult_result_d, mult_result_q;
  logic [riscv::XLEN*2-1:0] simd_mult_result_d, simd_mult_result_q;
  logic [riscv::XLEN*2-1:0] simd_mult_result_2;
  logic [riscv::XLEN:0] simd_smaqa_result_d, simd_smaqa_result_q;
  logic [riscv::XLEN:0] simd_smaqa64_result_d, simd_smaqa64_result_q;

  // control registers
  logic sign_a, sign_b;
  logic mult_valid;

  // control signals
  assign mult_valid_o = mult_valid_q;
  assign mult_trans_id_o = trans_id_q;
  assign mult_ready_o = 1'b1;

  assign mult_valid      = mult_valid_i && (operation_i inside {MUL, MULH, MULHU, MULHSU, MULW, CLMUL, CLMULH, CLMULR, SMUL8, UMUL8, SMAQA, SMAQA64, SMAQA128, SMAQA320});

  // Sign Select MUX
  always_comb begin
    sign_a = 1'b0;
    sign_b = 1'b0;

    // signed multiplication
    if (operation_i == MULH | operation_i == SMUL8) begin
      sign_a = 1'b1;
      sign_b = 1'b1;
    // unsigned - unsigned multiplication  
    end else if (operation_i == SMAQA | operation_i == SMAQA64 | operation_i == SMAQA128 | operation_i == SMAQA320) begin
      sign_a = 1'b0;
      sign_b = 1'b1;
    // signed - unsigned multiplication
    end else if (operation_i == MULHSU) begin
      sign_a = 1'b1;
      // unsigned multiplication
    end else begin
      sign_a = 1'b0;
      sign_b = 1'b0;
    end
  end


  // single stage version
  assign mult_result_d = $signed(
      {operand_a_i[riscv::XLEN-1] & sign_a, operand_a_i}
  ) * $signed(
      {operand_b_i[riscv::XLEN-1] & sign_b, operand_b_i}
  );
  
  // SIMD Multiplier 8 bits 
  // Y[63:48] = A[31:24] * B[31:24] 
  assign simd_mult_result_d[63:48] = $signed(
      {operand_a_i[31] & sign_a, operand_a_i[31:24]}
  ) * $signed(
      {operand_b_i[31] & sign_b, operand_b_i[31:24]}
  ); 
  // Y[47:32] = A[23:16] * B[23:16] 
  assign simd_mult_result_d[47:32] = $signed(
      {operand_a_i[23] & sign_a, operand_a_i[23:16]}
  ) * $signed(
      {operand_b_i[23] & sign_b, operand_b_i[23:16]}
  );
  // Y[31:16] = A[15:8] * B[15:8] 
  assign simd_mult_result_d[31:16] = $signed(
      {operand_a_i[15] & sign_a, operand_a_i[15:8]}
  ) * $signed(
      {operand_b_i[15] & sign_b, operand_b_i[15:8]}
  );  
  // Y[15:0] = A[7:0] * B[7:0] 
  assign simd_mult_result_d[15:0] = $signed(
      {operand_a_i[7] & sign_a, operand_a_i[7:0]}
  ) * $signed(
      {operand_b_i[7] & sign_b, operand_b_i[7:0]}
  );
  
  // SIMD SMAQA 8 bits 
  assign simd_smaqa_result_d = $signed(
      {simd_mult_result_d[63], simd_mult_result_d[63:48]}
  ) + $signed(
      {simd_mult_result_d[47], simd_mult_result_d[47:32]}
  ) + $signed(
      {simd_mult_result_d[31], simd_mult_result_d[31:16]}
  ) + $signed(
      {simd_mult_result_d[15], simd_mult_result_d[15:0]}
  ) + $signed(
      {operand_c_i[31], operand_c_i}
  );  
  
  // SMAQA 64 rs4 rs5
  
  // SIMD Multiplier 8 bits 
  // Y[63:48] = D[31:24] * E[31:24] 
  assign simd_mult_result_2[63:48] = $signed(
      {operand_d_i[31] & sign_a, operand_d_i[31:24]}
  ) * $signed(
      {operand_e_i[31] & sign_b, operand_e_i[31:24]}
  ); 
  // Y[47:32] = D[23:16] * E[23:16] 
  assign simd_mult_result_2[47:32] = $signed(
      {operand_d_i[23] & sign_a, operand_d_i[23:16]}
  ) * $signed(
      {operand_e_i[23] & sign_b, operand_e_i[23:16]}
  );
  // Y[31:16] = D[15:8] * E[15:8] 
  assign simd_mult_result_2[31:16] = $signed(
      {operand_d_i[15] & sign_a, operand_d_i[15:8]}
  ) * $signed(
      {operand_e_i[15] & sign_b, operand_e_i[15:8]}
  );  
  // Y[15:0] = D[7:0] * E[7:0] 
  assign simd_mult_result_2[15:0] = $signed(
      {operand_d_i[7] & sign_a, operand_d_i[7:0]}
  ) * $signed(
      {operand_e_i[7] & sign_b, operand_e_i[7:0]}
  );
  
  // SIMD SMAQA64 
  assign simd_smaqa64_result_d = $signed(
      {simd_mult_result_2[63], simd_mult_result_2[63:48]}
  ) + $signed(
      {simd_mult_result_2[47], simd_mult_result_2[47:32]}
  ) + $signed(
      {simd_mult_result_2[31], simd_mult_result_2[31:16]}
  ) + $signed(
      {simd_mult_result_2[15], simd_mult_result_2[15:0]}
  ) + $signed(
      {simd_smaqa_result_d[31], simd_smaqa_result_d}
  );
  
  
  //SMAQA128
  
  logic [riscv::XLEN*2-1:0] smaqa128_mult1_result, smaqa128_mult2_result, smaqa128_mult3_result, smaqa128_mult4_result;
  logic [riscv::XLEN:0] simd_smaqa128_result_q, simd_smaqa128_result_d;
  logic [31:0] inputs_buf_q[128:0];
  logic [6:0]  buf_pointer, buf_pointer_in;
  
  // SIMD Multiplier 8 bits 
  // Y[63:48] = A[31:24] * B[31:24] 
  assign smaqa128_mult1_result[63:48] = $signed(
      {inputs_buf_q[buf_pointer][31] & sign_a, inputs_buf_q[buf_pointer][31:24]}
  ) * $signed(
      {operand_a_i[31] & sign_b, operand_a_i[31:24]}
  ); 
  // Y[47:32] = A[23:16] * B[23:16] 
  assign smaqa128_mult1_result[47:32] = $signed(
      {inputs_buf_q[buf_pointer][23] & sign_a, inputs_buf_q[buf_pointer][23:16]}
  ) * $signed(
      {operand_a_i[23] & sign_b, operand_a_i[23:16]}
  );
  // Y[31:16] = A[15:8] * B[15:8] 
  assign smaqa128_mult1_result[31:16] = $signed(
      {inputs_buf_q[buf_pointer][15] & sign_a, inputs_buf_q[buf_pointer][15:8]}
  ) * $signed(
      {operand_a_i[15] & sign_b, operand_a_i[15:8]}
  );  
  // Y[15:0] = A[7:0] * B[7:0] 
  assign smaqa128_mult1_result[15:0] = $signed(
      {inputs_buf_q[buf_pointer][7] & sign_a, inputs_buf_q[buf_pointer][7:0]}
  ) * $signed(
      {operand_a_i[7] & sign_b, operand_a_i[7:0]}
  );
  
//    // SIMD Multiplier 8 bits 
//  // Y[63:48] = A[31:24] * B[31:24] 
//  assign smaqa128_mult2_result[63:48] = $signed(
//      {inputs_buf_q[buf_pointer + 1][31] & sign_a, inputs_buf_q[buf_pointer + 1][31:24]}
//  ) * $signed(
//      {operand_d_i[31] & sign_b, operand_d_i[31:24]}
//  ); 
//  // Y[47:32] = A[23:16] * B[23:16] 
//  assign smaqa128_mult2_result[47:32] = $signed(
//      {inputs_buf_q[buf_pointer + 1][23] & sign_a, inputs_buf_q[buf_pointer + 1][23:16]}
//  ) * $signed(
//      {operand_d_i[23] & sign_b, operand_d_i[23:16]}
//  );
//  // Y[31:16] = A[15:8] * B[15:8] 
//  assign smaqa128_mult2_result[31:16] = $signed(
//      {inputs_buf_q[buf_pointer + 1][15] & sign_a, inputs_buf_q[buf_pointer + 1][15:8]}
//  ) * $signed(
//      {operand_d_i[15] & sign_b, operand_d_i[15:8]}
//  );  
//  // Y[15:0] = A[7:0] * B[7:0] 
//  assign smaqa128_mult2_result[15:0] = $signed(
//      {inputs_buf_q[buf_pointer + 1][7] & sign_a, inputs_buf_q[buf_pointer + 1][7:0]}
//  ) * $signed(
//      {operand_d_i[7] & sign_b, operand_d_i[7:0]}
//  );
  
  // SIMD Multiplier 8 bits 
  // Y[63:48] = A[31:24] * B[31:24] 
  assign smaqa128_mult3_result[63:48] = $signed(
      {inputs_buf_q[buf_pointer + 1][31] & sign_a, inputs_buf_q[buf_pointer + 1][31:24]}
  ) * $signed(
      {operand_b_i[31] & sign_b, operand_b_i[31:24]}
  ); 
  // Y[47:32] = A[23:16] * B[23:16] 
  assign smaqa128_mult3_result[47:32] = $signed(
      {inputs_buf_q[buf_pointer + 1][23] & sign_a, inputs_buf_q[buf_pointer + 1][23:16]}
  ) * $signed(
      {operand_b_i[23] & sign_b, operand_b_i[23:16]}
  );
  // Y[31:16] = A[15:8] * B[15:8] 
  assign smaqa128_mult3_result[31:16] = $signed(
      {inputs_buf_q[buf_pointer + 1][15] & sign_a, inputs_buf_q[buf_pointer + 1][15:8]}
  ) * $signed(
      {operand_b_i[15] & sign_b, operand_b_i[15:8]}
  );  
  // Y[15:0] = A[7:0] * B[7:0] 
  assign smaqa128_mult3_result[15:0] = $signed(
      {inputs_buf_q[buf_pointer + 1][7] & sign_a, inputs_buf_q[buf_pointer + 1][7:0]}
  ) * $signed(
      {operand_b_i[7] & sign_b, operand_b_i[7:0]}
  );
  
//    // SIMD Multiplier 8 bits 
//  // Y[63:48] = A[31:24] * B[31:24] 
//  assign smaqa128_mult4_result[63:48] = $signed(
//      {inputs_buf_q[buf_pointer + 3][31] & sign_a, inputs_buf_q[buf_pointer + 3][31:24]}
//  ) * $signed(
//      {operand_e_i[31] & sign_b, operand_e_i[31:24]}
//  ); 
//  // Y[47:32] = A[23:16] * B[23:16] 
//  assign smaqa128_mult4_result[47:32] = $signed(
//      {inputs_buf_q[buf_pointer + 3][23] & sign_a, inputs_buf_q[buf_pointer + 3][23:16]}
//  ) * $signed(
//      {operand_e_i[23] & sign_b, operand_e_i[23:16]}
//  );
//  // Y[31:16] = A[15:8] * B[15:8] 
//  assign smaqa128_mult4_result[31:16] = $signed(
//      {inputs_buf_q[buf_pointer + 3][15] & sign_a, inputs_buf_q[buf_pointer + 3][15:8]}
//  ) * $signed(
//      {operand_e_i[15] & sign_b, operand_e_i[15:8]}
//  );  
//  // Y[15:0] = A[7:0] * B[7:0] 
//  assign smaqa128_mult4_result[15:0] = $signed(
//      {inputs_buf_q[buf_pointer + 3][7] & sign_a, inputs_buf_q[buf_pointer + 3][7:0]}
//  ) * $signed(
//      {operand_e_i[7] & sign_b, operand_e_i[7:0]}
//  );
    
  // SIMD SMAQA 8 bits 
  assign simd_smaqa128_result_d = $signed(
      {smaqa128_mult1_result[63], smaqa128_mult1_result[63:48]}
  ) + $signed(
      {smaqa128_mult1_result[47], smaqa128_mult1_result[47:32]}
  ) + $signed(
      {smaqa128_mult1_result[31], smaqa128_mult1_result[31:16]}
  ) + $signed(
      {smaqa128_mult1_result[15], smaqa128_mult1_result[15:0]}
//  ) + $signed(
//      {smaqa128_mult2_result[63], smaqa128_mult2_result[63:48]}
//  ) + $signed(
//      {smaqa128_mult2_result[47], smaqa128_mult2_result[47:32]}
//  ) + $signed(
//      {smaqa128_mult2_result[31], smaqa128_mult2_result[31:16]}
//  ) + $signed(
//      {smaqa128_mult2_result[15], smaqa128_mult2_result[15:0]}
  ) + $signed(
      {smaqa128_mult3_result[63], smaqa128_mult3_result[63:48]}
  ) + $signed(
      {smaqa128_mult3_result[47], smaqa128_mult3_result[47:32]}
  ) + $signed(
      {smaqa128_mult3_result[31], smaqa128_mult3_result[31:16]}
  ) + $signed(
      {smaqa128_mult3_result[15], smaqa128_mult3_result[15:0]}
//  ) + $signed(
//      {smaqa128_mult4_result[63], smaqa128_mult4_result[63:48]}
//  ) + $signed(
//      {smaqa128_mult4_result[47], smaqa128_mult4_result[47:32]}
//  ) + $signed(
//      {smaqa128_mult4_result[31], smaqa128_mult4_result[31:16]}
//  ) + $signed(
//      {smaqa128_mult4_result[15], smaqa128_mult4_result[15:0]}
  ) + $signed(
      {operand_c_i[31], operand_c_i}
  );  
  
  
   
  
  assign operator_d = operation_i;

  always_comb begin : p_selmux
    unique case (operator_q)
      MULH, MULHU, MULHSU: result_o = mult_result_q[riscv::XLEN*2-1:riscv::XLEN];
      MULW:                result_o = sext32(mult_result_q[31:0]);
      CLMUL:               result_o = clmul_q;
      CLMULH:              result_o = clmulr_q >> 1;
      CLMULR:              result_o = clmulr_q;
      SMUL8, UMUL8 :       result_o = simd_mult_result_q[riscv::XLEN-1:0];
      SMAQA:               result_o = simd_smaqa_result_q[riscv::XLEN-1:0];
      SMAQA64:             result_o = simd_smaqa64_result_q[riscv::XLEN-1:0];
      SMAQA128:            result_o = simd_smaqa128_result_q[riscv::XLEN-1:0];
                                
      // MUL performs an XLEN-bit×XLEN-bit multiplication and places the lower XLEN bits in the destination register
      
      default:             result_o = mult_result_q[riscv::XLEN-1:0];  // including MUL
    endcase
  end
  
    // SMAQA BUFFER
  always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        for (int i = 0; i < 128; i++) begin
            inputs_buf_q[i]  <= '0;
        end
        buf_pointer <= '0;
        buf_pointer_in <= '0;
        
      end else if (operator_q == SMAQA64) begin
        inputs_buf_q[buf_pointer_in]  <= operand_a_i;
        inputs_buf_q[buf_pointer_in + 1]  <= operand_d_i;
        buf_pointer_in <= buf_pointer_in + 2;
      end else if (operator_q == SMAQA128) begin
          if (buf_pointer == buf_pointer_in) begin
            buf_pointer <= '0; 
          end else
            buf_pointer <= buf_pointer + 2;
            
      end else if (operator_q == SMAQA320) begin
        buf_pointer <= '0;
        buf_pointer_in <= '0; 
      end else begin
       
      end
    end
  
  
  if (ariane_pkg::BITMANIP) begin
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        clmul_q  <= '0;
        clmulr_q <= '0;
      end else begin
        clmul_q  <= clmul_d;
        clmulr_q <= clmulr_d;
      end
    end
  end
  // -----------------------
  // Output pipeline register
  // -----------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mult_valid_q  <= '0;
      trans_id_q    <= '0;
      operator_q    <= MUL;
      mult_result_q <= '0;
      simd_mult_result_q <= '0;
    end else begin
      // Input silencing
      trans_id_q    <= trans_id_i;
      // Output Register
      mult_valid_q  <= mult_valid;
      operator_q    <= operator_d;
      mult_result_q <= mult_result_d;
      simd_mult_result_q <= simd_mult_result_d;
      simd_smaqa_result_q <= simd_smaqa_result_d;
      simd_smaqa64_result_q <= simd_smaqa64_result_d;
      simd_smaqa128_result_q <= simd_smaqa128_result_d;
    end
  end
endmodule
