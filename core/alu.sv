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
// Author: Matthias Baer <baermatt@student.ethz.ch>
// Author: Igor Loi <igor.loi@unibo.it>
// Author: Andreas Traber <atraber@student.ethz.ch>
// Author: Lukas Mueller <lukasmue@student.ethz.ch>
// Author: Florian Zaruba <zaruabf@iis.ee.ethz.ch>
//
// Date: 19.03.2017
// Description: Ariane ALU based on RI5CY's ALU


module alu
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input  logic         clk_i, // Clock
    input  logic         rst_ni, // Asynchronous reset active low
    input  fu_data_t     fu_data_i,
    output riscv::xlen_t result_o,
    output logic         alu_branch_res_o
);

    riscv::xlen_t                   operand_a_rev;
    logic         [           31:0] operand_a_rev32;
    logic         [  riscv::XLEN:0] operand_b_neg;
    logic         [riscv::XLEN+1:0] adder_result_ext_o;
    logic                           less; // handles both signed and unsigned forms
    logic         [           31:0] rolw; // Rotate Left Word
    logic         [           31:0] rorw; // Rotate Right Word
    logic [31:0] orcbw, rev8w;
    logic [  $clog2(riscv::XLEN) : 0] cpop; // Count Population
    logic [$clog2(riscv::XLEN)-1 : 0] lz_tz_count; // Count Leading Zeros
    logic [                      4:0] lz_tz_wcount; // Count Leading Zeros Word
    logic lz_tz_empty, lz_tz_wempty;
    riscv::xlen_t orcbw_result, rev8w_result;

    // bit reverse operand_a for left shifts and bit counting
    generate
        genvar k;
        for (k = 0; k < riscv::XLEN; k++)
            assign operand_a_rev[k] = fu_data_i.operand_a[riscv::XLEN-1-k];

        for (k = 0; k < 32; k++) assign operand_a_rev32[k] = fu_data_i.operand_a[31-k];
    endgenerate

    // ------
    // Adder
    // ------
    logic adder_op_b_negate;
    logic adder_z_flag;
    logic [riscv::XLEN:0] adder_in_a, adder_in_b;
    riscv::xlen_t adder_result;
    logic [riscv::XLEN-1:0] operand_a_bitmanip, bit_indx;

    always_comb begin
        adder_op_b_negate = 1'b0;

        unique case (fu_data_i.operation)
            // ADDER OPS
            EQ, NE, SUB, SUBW, ANDN, ORN, XNOR: adder_op_b_negate = 1'b1;
            default: ;
        endcase
    end

    always_comb begin
        operand_a_bitmanip = fu_data_i.operand_a;

        if (ariane_pkg::BITMANIP) begin
            unique case (fu_data_i.operation)
                SH1ADD:             operand_a_bitmanip = fu_data_i.operand_a << 1;
                SH2ADD:             operand_a_bitmanip = fu_data_i.operand_a << 2;
                SH3ADD:             operand_a_bitmanip = fu_data_i.operand_a << 3;
                SH1ADDUW:           operand_a_bitmanip = fu_data_i.operand_a[31:0] << 1;
                SH2ADDUW:           operand_a_bitmanip = fu_data_i.operand_a[31:0] << 2;
                SH3ADDUW:           operand_a_bitmanip = fu_data_i.operand_a[31:0] << 3;
                CTZ:                operand_a_bitmanip = operand_a_rev;
                CTZW:               operand_a_bitmanip = operand_a_rev32;
                ADDUW, CPOPW, CLZW: operand_a_bitmanip = fu_data_i.operand_a[31:0];
                default:            ;
            endcase
        end
    end

    // prepare operand a
    assign adder_in_a         = {operand_a_bitmanip, 1'b1};

    // prepare operand b
    assign operand_b_neg      = {fu_data_i.operand_b, 1'b0} ^ {riscv::XLEN + 1{adder_op_b_negate}};
    assign adder_in_b         = operand_b_neg;

    // actual adder
    assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);
    assign adder_result       = adder_result_ext_o[riscv::XLEN:1];
    assign adder_z_flag       = ~|adder_result;

    // get the right branch comparison result
    always_comb begin : branch_resolve
        // set comparison by default
        alu_branch_res_o = 1'b1;
        case (fu_data_i.operation)
            EQ:       alu_branch_res_o = adder_z_flag;
            NE:       alu_branch_res_o = ~adder_z_flag;
            LTS, LTU: alu_branch_res_o = less;
            GES, GEU: alu_branch_res_o = ~less;
            default:  alu_branch_res_o = 1'b1;
        endcase
    end

    // ------
    // SIMD Adder
    // ------

    logic simd_adder_op_b_negate;
    logic simd_adder_z_flag;
    logic vsize; //Size of the vector : for 16 bits vsize = 1, for 8bit vsize =0
    logic sext; //Sign extension : sext = 1, Zero extension : sext = 0
    logic halving; //Halving operation : halving = 1, else : halving = 0
    logic u_overflow0, u_overflow1, u_overflow2, u_overflow3; //Unsigned overflow logic signals  
    logic p_overflow0, p_overflow1, p_overflow2, p_overflow3; //Positive overflow logic signals 
    logic n_overflow0, n_overflow1, n_overflow2, n_overflow3; //Negative overflow logic signals  
    logic cross_op_b; // Cross operation : cross_op = 1 ; Straight operation : cross_op = 0
    logic op_b_negate_up, op_b_negate_down; // Add and sub operation : op_b_negate_up = 0, op_b_negate_down = 1 ;  Sub and Add operation : op_b_negate_up = 1, op_b_negate_down = 0 ; Else (Non add&sub operations) : op_b_negate_up = 0, op_b_negate_down = 0
    logic [8:0] adder_in_a0, adder_in_a1, adder_in_a2, adder_in_a3, adder_in_b0,adder_in_b1, adder_in_b2,adder_in_b3;
    logic [riscv::XLEN-1:0] simd_adder_result, result;
    logic [riscv::XLEN-1:0] simd_operand_a_bitmanip, simd_bit_indx;
    logic [8:0] add0, add1, add2, add3;
    logic c_out0, c_out1, c_out2, c_out3;

    // Select SIMD Vector size (8 or 16 bits)
    always_comb begin
        vsize = 1'b1;

        unique case (fu_data_i.operation)
            // VECTOR SIZE 
            ADD8, SUB8, RADD8, URADD8, RSUB8, URSUB8, KADD8, UKADD8, KSUB8, UKSUB8: vsize = 1'b0; //8 bits   
            ADD16, SUB16, RADD16, URADD16, RSUB16, URSUB16, KADD16, UKADD16, KSUB16, UKSUB16, CRAS16, RCRAS16, URCRAS16, KCRAS16, UKCRAS16, CRSA16, RCRSA16, URCRSA16, KCRSA16, UKCRSA16, STAS16, RSTAS16, URSTAS16, KSTAS16, UKSTAS16, STSA16, RSTSA16, URSTSA16, KSTSA16, UKSTSA16: vsize = 1'b1; //16 bits 
            default: ;
        endcase
    end

    // Select between sign extension and zero extension 
    always_comb begin
        sext = 1'b0;

        unique case (fu_data_i.operation)
            // Extension
            ADD8, SUB8, ADD16, SUB16, URADD8, URSUB8, URADD16, URSUB16, UKADD16, UKSUB16, UKADD8, UKSUB8, CRAS16,URCRAS16, UKCRAS16, CRSA16, URCRSA16, UKCRSA16, STAS16, URSTAS16, UKSTAS16, STSA16, URSTSA16, UKSTSA16, ZUNPKD810, ZUNPKD820, ZUNPKD830, ZUNPKD831, ZUNPKD832  : sext = 1'b0; //Zero extend 
            RADD8, RSUB8, RADD16, RSUB16, KADD16, KSUB16, KADD8, KSUB8, RCRAS16, KCRAS16, RCRSA16, KCRSA16, RSTAS16, KSTAS16, RSTSA16, KSTSA16, SUNPKD810, SUNPKD820, SUNPKD830, SUNPKD831, SUNPKD832 : sext = 1'b1; //Sign extend 
            default: ;
        endcase
    end

    // Halving operations
    always_comb begin
        halving = 1'b0;

        unique case (fu_data_i.operation)
            RADD8, RSUB8, RADD16, RSUB16, URADD16, URSUB16, URSUB8, RCRAS16, URCRAS16, RCRSA16, URCRSA16, RSTAS16, URSTAS16, RSTSA16, URSTSA16 : halving = 1'b1; //Halving operations  
            default: ;
        endcase
    end

    // Negate operand B for SUB operations 
    always_comb begin
        simd_adder_op_b_negate = 1'b0;

        unique case (fu_data_i.operation)
            // ADDER OPS
            SUB8, SUB16, RSUB8, RSUB16, URSUB8, URSUB16, KSUB16, UKSUB16, KSUB8, UKSUB8: simd_adder_op_b_negate = 1'b1;
            default: ;
        endcase
    end

    // Negate operand b up or down part for Add and Sub / Sub and Add operations (16bits)
    always_comb begin
        op_b_negate_up = 1'b0;
        op_b_negate_down = 1'b0;

        unique case (fu_data_i.operation)
            CRAS16, RCRAS16, URCRAS16, KCRAS16, UKCRAS16, STAS16, RSTAS16, URSTAS16, KSTAS16, UKSTAS16 : op_b_negate_down = 1'b1;
            CRSA16, RCRSA16, URCRSA16, KCRSA16, UKCRSA16, STSA16, RSTSA16, URSTSA16, KSTSA16, UKSTSA16 : op_b_negate_up = 1'b1;
            default: ;
        endcase
    end

    // Cross operand b up part with down part for Crossing operations (16bits)
    always_comb begin
        cross_op_b = 1'b0;

        unique case (fu_data_i.operation)
            CRAS16, RCRAS16, URCRAS16, KCRAS16, UKCRAS16, CRSA16, RCRSA16, URCRSA16, KCRSA16, UKCRSA16 : cross_op_b = 1'b1;
            default: ;
        endcase
    end


    // Prepare operand a : a0 = a[7:0], a1 = a[15:8], a2 = a[23:16], a3 = a[31:24] 
    // Perform zero extension or sign extension depending on the instruction 
    assign adder_in_a0         = {fu_data_i.operand_a[7]  & sext & ~vsize ,fu_data_i.operand_a[7:0]};
    assign adder_in_a1         = {fu_data_i.operand_a[15] & sext           ,fu_data_i.operand_a[15:8]};
    assign adder_in_a2         = {fu_data_i.operand_a[23] & sext & ~vsize ,fu_data_i.operand_a[23:16]};
    assign adder_in_a3         = {fu_data_i.operand_a[31] & sext           ,fu_data_i.operand_a[31:24]};

    // prepare operand b : b0 = b[7:0], b1 = b[15:8], b2 = b[23:16], b3 = b[31:24] 
    // Perform zero extension or sign extension depending on the instruction  
    assign adder_in_b0         = {((fu_data_i.operand_b[7] & ~cross_op_b) | (fu_data_i.operand_b[23] & cross_op_b))  & sext & ~vsize ,(fu_data_i.operand_b[7:0] & {8{~cross_op_b}}) | (fu_data_i.operand_b[23:16] & {8{cross_op_b}})} ^ {(simd_adder_op_b_negate | op_b_negate_down) & halving & ~vsize, {8{(simd_adder_op_b_negate | op_b_negate_down)}}};
    assign adder_in_b1         = {((fu_data_i.operand_b[15] & ~cross_op_b) | (fu_data_i.operand_b[31] & cross_op_b))  & sext         ,(fu_data_i.operand_b[15:8] & {8{~cross_op_b}}) | (fu_data_i.operand_b[31:24] & {8{cross_op_b}})} ^ {(simd_adder_op_b_negate | op_b_negate_down) & halving, {8{(simd_adder_op_b_negate | op_b_negate_down)}}};
    assign adder_in_b2         = {((fu_data_i.operand_b[23] & ~cross_op_b) | (fu_data_i.operand_b[7] & cross_op_b)) & sext & ~vsize ,(fu_data_i.operand_b[23:16] & {8{~cross_op_b}}) | (fu_data_i.operand_b[7:0] & {8{cross_op_b}})} ^ {(simd_adder_op_b_negate | op_b_negate_up) & halving & ~vsize, {8{(simd_adder_op_b_negate | op_b_negate_up)}}};
    assign adder_in_b3         = {((fu_data_i.operand_b[31] & ~cross_op_b) | (fu_data_i.operand_b[15] & cross_op_b)) & sext         ,(fu_data_i.operand_b[31:24] & {8{~cross_op_b}}) | (fu_data_i.operand_b[15:8] & {8{cross_op_b}})} ^ {(simd_adder_op_b_negate | op_b_negate_up) & halving, {8{(simd_adder_op_b_negate | op_b_negate_up)}}};


    // actual adder
    //adder 0 
    assign add0 = $unsigned(adder_in_a0) + $unsigned(adder_in_b0) + {{8{0}}, (simd_adder_op_b_negate | op_b_negate_down)};
    assign c_out0 = add0[8];
    assign u_overflow0 = add0[8]^(simd_adder_op_b_negate | op_b_negate_down);
    assign p_overflow0 = (~fu_data_i.operand_a[7]) & (~fu_data_i.operand_b[7]^(simd_adder_op_b_negate | op_b_negate_down)) & add0[7];
    assign n_overflow0 = fu_data_i.operand_a[7] & (fu_data_i.operand_b[7]^(simd_adder_op_b_negate | op_b_negate_down)) & (~add0[7]);

    //adder 1
    assign add1 = $unsigned(adder_in_a1) + $unsigned(adder_in_b1) + {{8{0}}, ((simd_adder_op_b_negate | op_b_negate_down) & ~vsize)  | (c_out0 & vsize)};
    assign c_out1 = add1[8];
    assign u_overflow1 = add1[8]^(simd_adder_op_b_negate | op_b_negate_down);
    assign p_overflow1 = (~fu_data_i.operand_a[15]) & ((~fu_data_i.operand_b[15])^(simd_adder_op_b_negate | op_b_negate_down)) & add1[7];
    assign n_overflow1 = fu_data_i.operand_a[15] & (fu_data_i.operand_b[15]^(simd_adder_op_b_negate | op_b_negate_down)) & (~add1[7]);

    //adder 2
    assign add2 = $unsigned(adder_in_a2) + $unsigned(adder_in_b2) + {{8{0}}, (simd_adder_op_b_negate | op_b_negate_up)};
    assign c_out2 = add2[8];
    assign u_overflow2 = add2[8]^(simd_adder_op_b_negate | op_b_negate_up);
    assign p_overflow2 = (~fu_data_i.operand_a[23]) & ((~fu_data_i.operand_b[23])^(simd_adder_op_b_negate | op_b_negate_up)) & add2[7];
    assign n_overflow2 = fu_data_i.operand_a[23] & (fu_data_i.operand_b[23]^(simd_adder_op_b_negate | op_b_negate_up)) & (~add2[7]);
    //adder 3
    assign add3 = $unsigned(adder_in_a3) + $unsigned(adder_in_b3) + {{8{0}}, ((simd_adder_op_b_negate | op_b_negate_up) & ~vsize) | (c_out2 & vsize)};
    assign c_out3 = add3[8];
    assign u_overflow3 = add3[8]^(simd_adder_op_b_negate | op_b_negate_up);
    assign p_overflow3 = (~fu_data_i.operand_a[31]) & ((~fu_data_i.operand_b[31])^(simd_adder_op_b_negate | op_b_negate_up)) & add3[7];
    assign n_overflow3 = fu_data_i.operand_a[31] & (fu_data_i.operand_b[31]^(simd_adder_op_b_negate | op_b_negate_up)) & (~add3[7]);

    //adder result 
    always_comb begin
        result = {add3[7:0], add2[7:0], add1[7:0], add0[7:0]};

        unique case (fu_data_i.operation)
            ADD8, SUB8, ADD16, SUB16 :  result = {add3[7:0], add2[7:0], add1[7:0], add0[7:0]};
            UKADD16, UKSUB16, UKADD8, UKSUB8, UKCRAS16, UKCRSA16, UKSTAS16, UKSTSA16 : result = {u_overflow3 ? {8{~(simd_adder_op_b_negate | op_b_negate_up)}} : add3[7:0] ,
            ((u_overflow2 & ~vsize) | (u_overflow3 & vsize)) ? {8{~(simd_adder_op_b_negate | op_b_negate_up)}} : add2[7:0],
            u_overflow1 ? {8{~(simd_adder_op_b_negate | op_b_negate_down)}} : add1[7:0],
            ((u_overflow0 & ~vsize) | (u_overflow1 & vsize)) ? {8{~(simd_adder_op_b_negate | op_b_negate_down)}} : add0[7:0]}; //Unsigned saturated operation

            KADD16, KSUB16, KADD8, KSUB8, KCRAS16, KCRSA16, KSTAS16, KSTSA16 : result = {(p_overflow3 | n_overflow3)? {8'h7F}^{8{n_overflow3}} : add3[7:0] ,
            (((p_overflow2 | n_overflow2) & ~vsize) ? {8'h7F}^{8{n_overflow2}} : (((p_overflow3 | n_overflow3) & vsize)) ? {8'hFF}^{8{n_overflow3}} : add2[7:0]),
            (p_overflow1 | n_overflow1)? {8'h7F}^{8{n_overflow1}} : add1[7:0],
            (((p_overflow0 | n_overflow0) & ~vsize) ? {8'h7F}^{8{n_overflow0}} : (((p_overflow1 | n_overflow1) & vsize)) ? {8'hFF}^{8{n_overflow1}} : add0[7:0])}; //Signed saturated operation

            RADD8, RSUB8, URADD8, URSUB8 : result = {add3[8:1], add2[8:1], add1[8:1], add0[8:1]}; //Halving 8 bits
            RADD16, RSUB16, URADD16, URSUB16, RCRAS16, URCRAS16, RCRSA16, URCRSA16, RSTAS16, URSTAS16, RSTSA16, URSTSA16 : result = {add3[8:0], add2[7:1], add1[8:0], add0[7:1]}; //Halving 16 bits
            default:            ;
        endcase
    end


    assign simd_adder_result       = result;
    assign simd_adder_z_flag       = ~|simd_adder_result;



    // ---------
    // Shifts
    // ---------

    // TODO: this can probably optimized significantly
    logic                         shift_left; // should we shift left
    logic                         shift_arithmetic;

    riscv::xlen_t                 shift_amt; // amount of shift, to the right
    riscv::xlen_t                 shift_op_a; // input of the shifter
    logic         [         31:0] shift_op_a32; // input to the 32 bit shift operation

    riscv::xlen_t                 shift_result;
    logic         [         31:0] shift_result32;

    logic         [riscv::XLEN:0] shift_right_result;
    logic         [         32:0] shift_right_result32;

    riscv::xlen_t                 shift_left_result;
    logic         [         31:0] shift_left_result32;

    assign shift_amt = fu_data_i.operand_b;

    assign shift_left = (fu_data_i.operation == SLL) | (fu_data_i.operation == SLLW);

    assign shift_arithmetic = (fu_data_i.operation == SRA) | (fu_data_i.operation == SRAW);

    // right shifts, we let the synthesizer optimize this
    logic [riscv::XLEN:0] shift_op_a_64;
    logic [32:0] shift_op_a_32;

    // choose the bit reversed or the normal input for shift operand a
    assign shift_op_a           = shift_left ? operand_a_rev : fu_data_i.operand_a;
    assign shift_op_a32         = shift_left ? operand_a_rev32 : fu_data_i.operand_a[31:0];

    assign shift_op_a_64        = {shift_arithmetic & shift_op_a[riscv::XLEN-1], shift_op_a};
    assign shift_op_a_32        = {shift_arithmetic & shift_op_a[31], shift_op_a32};

    assign shift_right_result   = $unsigned($signed(shift_op_a_64) >>> shift_amt[5:0]);

    assign shift_right_result32 = $unsigned($signed(shift_op_a_32) >>> shift_amt[4:0]);
    // bit reverse the shift_right_result for left shifts
    genvar j;
    generate
        for (j = 0; j < riscv::XLEN; j++)
            assign shift_left_result[j] = shift_right_result[riscv::XLEN-1-j];

        for (j = 0; j < 32; j++) assign shift_left_result32[j] = shift_right_result32[31-j];

    endgenerate

    assign shift_result   = shift_left ? shift_left_result : shift_right_result[riscv::XLEN-1:0];
    assign shift_result32 = shift_left ? shift_left_result32 : shift_right_result32[31:0];


    // ---------
    // SIMD Shifts
    // ---------

    // TODO: this can probably optimized significantly
    logic                simd_shift_left; // should we shift left
    logic                simd_shift_arithmetic;
    logic          [3:0] simd_shift_rounding; //Rounding shift operations 
    logic          [3:0] simd_shift_temp_amt16; 
    logic          [2:0] simd_shift_temp_amt8; 

    riscv::xlen_t        simd_shift_amt; // amount of shift, to the right

    logic         [31:0] simd_shift_op_a; // input to the shift operation

    logic         [31:0] simd_shift_result8;
    logic         [31:0] simd_shift_result16;

    logic         [31:0] simd_shift_right8; // Result after performing shift for SIMD 8 bits 
    logic         [31:0] simd_shift_right16; // Result after performing shift for SIMD 16 bits 

    logic         [31:0] masked_simd_shift_right_result8; // Result after applying the first mask to get rid of unwanted bits for 8 bits SIMD operation  
    logic         [31:0] masked_simd_shift_right_result16; // Result after applying the first mask to get rid of unwanted bits for 16 bits SIMD operation     

    logic         [31:0] simd_shift_right_result8;  ; // Final result of SIMD shift right operation (8 bits elements)
    logic         [31:0] simd_shift_right_result16; // Final result of SIMD shift right operation (16 bits elements)

    logic         [31:0] simd_shift_left_result8; // Final result of SIMD shift left operation (8 bits elements)
    logic         [31:0] simd_shift_left_result16; // Final result of SIMD shift left operation (16 bits elements)

    logic         [31:0] simd_mask8, simd_sign_mask8, simd_mask16, simd_sign_mask16, inv_mask8, inv_mask16; //Unwanted bits mask and sign mask 

    logic         [7:0]  temp_mask8;
    logic         [15:0] temp_mask16;


    assign simd_shift_amt = fu_data_i.operand_b;

    // Select shift left or right  
    always_comb begin
        simd_shift_left = 1'b0; //Shift right

        unique case (fu_data_i.operation)
            SLL16, KSLL16, KSLRA16, KSLRA16_U, SLL8, KSLL8, KSLRA8, KSLRA8_U : simd_shift_left = 1'b1; //Shift left             
            default: ;
        endcase
    end

    // Select shift logical or arithmetic  
    always_comb begin
        simd_shift_arithmetic = 1'b0; //Logical shift 

        unique case (fu_data_i.operation)
            SRA16, SRA16_U, KSLRA16, KSLRA16_U,SRA8, SRA8_U, KSLRA8, KSLRA8_U  : simd_shift_arithmetic = 1'b1; //Arithmetic shift          
            default: ;
        endcase
    end    
    
    // Rounding shift operations 
    always_comb begin
        simd_shift_rounding = 4'b0; //No rounding

        unique case (fu_data_i.operation)
            SRA16_U, SRL16_U, KSLRA16_U, SRA8_U, SRL8_U, KSLRA8_U  : simd_shift_rounding= 4'b0001; //Rounding operation          
            default: ;
        endcase
    end

    // choose the bit reversed or the normal input for shift operand a
    assign simd_shift_op_a = simd_shift_left ? operand_a_rev32 : fu_data_i.operand_a[31:0];
    
    //
    assign simd_shift_temp_amt8 = simd_shift_amt[2:0] - simd_shift_rounding[2:0];
    assign simd_shift_temp_amt16 = simd_shift_amt[3:0] - simd_shift_rounding[3:0];
    
    // Perform right shift 
    assign simd_shift_right8   = $unsigned($unsigned(simd_shift_op_a) >>> simd_shift_temp_amt8);
    assign simd_shift_right16  = $unsigned($unsigned(simd_shift_op_a) >>> simd_shift_temp_amt16);

    // First mask : consists of a number of zeros equal to the shift amount while the rest is set to one
    
    always_comb begin
    
        temp_mask8 = (simd_shift_temp_amt8  == 0) ? 8'b11111111 :
        (simd_shift_temp_amt8 == 1) ? 8'b01111111 :
        (simd_shift_temp_amt8 == 2) ? 8'b00111111 :
        (simd_shift_temp_amt8 == 3) ? 8'b00011111 :
        (simd_shift_temp_amt8 == 4) ? 8'b00001111 :
        (simd_shift_temp_amt8 == 5) ? 8'b00000111 :
        (simd_shift_temp_amt8 == 6) ? 8'b00000011 :
        (simd_shift_temp_amt8 == 7) ? 8'b00000001 :
        (simd_shift_temp_amt8 == 8) ? 8'b00000000 :
        8'b11111111;

        temp_mask16 = (simd_shift_temp_amt16 == 0) ? 16'b1111111111111111 :
        (simd_shift_temp_amt16 == 1) ? 16'b0111111111111111 :
        (simd_shift_temp_amt16 == 2) ? 16'b0011111111111111 :
        (simd_shift_temp_amt16 == 3) ? 16'b0001111111111111 :
        (simd_shift_temp_amt16 == 4) ? 16'b0000111111111111 :
        (simd_shift_temp_amt16 == 5) ? 16'b0000011111111111 :
        (simd_shift_temp_amt16 == 6) ? 16'b0000001111111111 :
        (simd_shift_temp_amt16 == 7) ? 16'b0000000111111111 :
        (simd_shift_temp_amt16 == 8) ? 16'b0000000011111111 :
        (simd_shift_temp_amt16 == 9) ? 16'b0000000001111111 :
        (simd_shift_temp_amt16 == 10) ? 16'b0000000000111111 :
        (simd_shift_temp_amt16 == 11) ? 16'b0000000000011111 :
        (simd_shift_temp_amt16 == 12) ? 16'b0000000000001111 :
        (simd_shift_temp_amt16 == 13) ? 16'b0000000000000111 :
        (simd_shift_temp_amt16 == 14) ? 16'b0000000000000011 :
        (simd_shift_temp_amt16 == 15) ? 16'b0000000000000001 :
        16'b1111111111111111;
    end



    assign simd_mask8 = {4{temp_mask8}};
    assign simd_mask16 = {2{temp_mask16}};

    // By performing an AND operation with the mask and the shift result, the unwanted bits get cancelled out  
    assign masked_simd_shift_right_result8   = simd_shift_right8 & simd_mask8;
    assign masked_simd_shift_right_result16  = simd_shift_right16 & simd_mask16;

    // Second mask : constructed by taking the inverse of the original mask and performing an AND operation with the sign bit of that element. 
    //               This results in a mask that has the sign bit replicated as many times as the shift amount and the rest of the bits equal to zero
    assign inv_mask8 = ~(simd_mask8);
    assign inv_mask16 = ~(simd_mask16);
    assign simd_sign_mask8 = {inv_mask8[31:24] & {8{simd_shift_op_a[31]}},inv_mask8[23:16] & {8{simd_shift_op_a[23]}},inv_mask8[15:8] & {8{simd_shift_op_a[15]}},inv_mask8[7:0] & {8{simd_shift_op_a[7]}}};
    assign simd_sign_mask16 = {inv_mask16[31:16] & {16{simd_shift_op_a[31]}},inv_mask16[15:0] & {16{simd_shift_op_a[15]}}};

    //By applying an OR operation with this mask on the result of the previous mask application, the sign bits get correctly inserted and an arithmetic shift is realized
    assign simd_shift_right_result8 = masked_simd_shift_right_result8 | (simd_sign_mask8 & {32{simd_shift_arithmetic}});
    assign simd_shift_right_result16 = masked_simd_shift_right_result16 | (simd_sign_mask16 & {32{simd_shift_arithmetic}});
    

    // bit reverse the shift_right_result for left shifts
    genvar l;
    generate

        for (l = 0; l < 32; l++)
            assign simd_shift_left_result8[l] = simd_shift_right_result8[31-l];
        for (l = 0; l < 32; l++)
            assign simd_shift_left_result16[l] = simd_shift_right_result16[31-l];


    endgenerate

    assign simd_shift_result8 = simd_shift_left ? simd_shift_left_result8 : simd_shift_right_result8;
    assign simd_shift_result16 = simd_shift_left ? simd_shift_left_result16 : simd_shift_right_result16;

    // ------------
    // Comparisons
    // ------------

    always_comb begin
        logic sgn;
        sgn = 1'b0;

        if ((fu_data_i.operation == SLTS) ||
        (fu_data_i.operation == LTS)  ||
        (fu_data_i.operation == GES)  ||
        (fu_data_i.operation == MAX)  ||
        (fu_data_i.operation == MIN))
            sgn = 1'b1;

        less = ($signed({sgn & fu_data_i.operand_a[riscv::XLEN-1], fu_data_i.operand_a}) <
        $signed({sgn & fu_data_i.operand_b[riscv::XLEN-1], fu_data_i.operand_b}));
    end
    
    // ------------
    // SIMD Comparisons
    // ------------
    logic less0_16, less1_16, eq0_16, eq1_16; // SIMD 16 bits : (opA[15:0] < opB[15:0]), (opA[31:16] < opB[31:16]), (opA[15:0] == opB[15:0]), (opA[31:16] == opB[31:16])
    logic less0_8, less1_8,less2_8, less3_8, eq0_8, eq1_8, eq2_8, eq3_8; // SIMD 8 bits : (opA[7:0] < opB[7:0]), (opA[15:8] < opB[15:8]) ... 
    
    logic [15:0]   simd16_comparisons_res1, simd16_comparisons_res0; // SIMD 16 bits Comparisons results (res[31:16] and res[15:0])
    logic [15:0]   simd16_min_res1, simd16_min_res0; // SIMD 16 bits Min/Max results (res[31:16] and res[15:0])
    
    logic [7:0]   simd8_comparisons_res3, simd8_comparisons_res2,simd8_comparisons_res1, simd8_comparisons_res0; // SIMD 8 bits Comparisons results (res[31:24], res[23:16], res[15:8], res[7:0])
    logic [7:0]   simd8_min_res3, simd8_min_res2,simd8_min_res1, simd8_min_res0; // SIMD 8 bits Min/Max results (res[31:24], res[23:16], res[15:8], res[7:0])
    
    logic [31:0]   simd16_comparisons_result; // SIMD Comparisons 16 bits final result 
    logic [31:0]   simd8_comparisons_result; // SIMD Comparisons 8 bits final result 
    
    logic [31:0]   simd16_min_result; // SIMD Max/Min 16 bits final result 
    logic [31:0]   simd8_min_result; // SIMD Max/Min 8 bits final result 
    
    
    always_comb begin
        logic simd_sgn;
        logic leq_op;
        logic eq_op;
        logic min;
        simd_sgn = 1'b0; // Signed operations
        eq_op = 1'b0;    // Equal operation 
        leq_op = 1'b0;   // (Less than & equal operations) and (Equal operations)  
        min = 1'b0;      // MIN operation : min = 1, MAX operation = 0  

        if ((fu_data_i.operation == SCMPLT16) ||
        (fu_data_i.operation == SCMPLE16)  ||
        (fu_data_i.operation == SCMPLT8)  ||
        (fu_data_i.operation == SCMPLE8)  || 
        (fu_data_i.operation == SMIN16) ||
        (fu_data_i.operation == SMAX16) ||
        (fu_data_i.operation == SMIN8)  ||
        (fu_data_i.operation == SMAX8))  
            simd_sgn = 1'b1;
 

        if ((fu_data_i.operation == SCMPLE8) ||
        (fu_data_i.operation == UCMPLE8)  ||
        (fu_data_i.operation == SCMPLE16)  ||
        (fu_data_i.operation == UCMPLE16) ||
        (fu_data_i.operation == CMPEQ16) ||
        (fu_data_i.operation == CMPEQ8))
            leq_op = 1'b1;
            
        if ((fu_data_i.operation == CMPEQ16) ||
        (fu_data_i.operation == CMPEQ8))
            eq_op = 1'b1;    
            
        if ((fu_data_i.operation == SMIN16) ||
        (fu_data_i.operation == UMIN16) ||
        (fu_data_i.operation == SMIN8) ||
        (fu_data_i.operation == UMIN8))
            min = 1'b1;       
         
           
        //SIMD 16 bits comparisons 
        
        less1_16 = ($signed({simd_sgn & fu_data_i.operand_a[31], fu_data_i.operand_a[31:16]}) <
        $signed({simd_sgn & fu_data_i.operand_b[31], fu_data_i.operand_b[31:16]}));        
        eq1_16 =   (fu_data_i.operand_a[31:16] == fu_data_i.operand_b[31:16]);
        simd16_comparisons_res1 = (less1_16 & ~eq_op) | (eq1_16 & leq_op) ? 16'hffff : 0;
        simd16_min_res1 = less1_16? (fu_data_i.operand_a[31:16] & {16{min}}) | (fu_data_i.operand_b[31:16] & {16{~min}}) : (fu_data_i.operand_a[31:16] & {16{~min}}) | (fu_data_i.operand_b[31:16] & {16{min}});
            
        less0_16 = ($signed({simd_sgn & fu_data_i.operand_a[15], fu_data_i.operand_a[15:0]}) <
        $signed({simd_sgn & fu_data_i.operand_b[15], fu_data_i.operand_b[15:0]}));       
        eq0_16 =   (fu_data_i.operand_a[15:0] == fu_data_i.operand_b[15:0]);
        simd16_comparisons_res0 = (less0_16 & ~eq_op) | (eq0_16 & leq_op) ? 16'hffff : 0;
        simd16_min_res0 = less0_16? (fu_data_i.operand_a[15:0] & {16{min}}) | (fu_data_i.operand_b[15:0] & {16{~min}}) : (fu_data_i.operand_a[15:0] & {16{~min}}) | (fu_data_i.operand_b[15:0] & {16{min}});
        
        //SIMD 8 bits comparisons 
        
        less3_8 = ($signed({simd_sgn & fu_data_i.operand_a[31], fu_data_i.operand_a[31:24]}) <
        $signed({simd_sgn & fu_data_i.operand_b[31], fu_data_i.operand_b[31:24]}));        
        eq3_8 = (fu_data_i.operand_a[31:24] == fu_data_i.operand_b[31:24]);
        simd8_comparisons_res3 = (less3_8 & ~eq_op) | (eq3_8 & leq_op) ? 8'hff : 0;
        simd8_min_res3 = less3_8? (fu_data_i.operand_a[31:24] & {8{min}}) | (fu_data_i.operand_b[31:24] & {8{~min}}) : (fu_data_i.operand_a[31:24] & {8{~min}}) | (fu_data_i.operand_b[31:24] & {8{min}});
               
        less2_8 = ($signed({simd_sgn & fu_data_i.operand_a[23], fu_data_i.operand_a[23:16]}) <
        $signed({simd_sgn & fu_data_i.operand_b[23], fu_data_i.operand_b[23:16]}));  
        eq2_8 = (fu_data_i.operand_a[23:16] == fu_data_i.operand_b[23:16]);
        simd8_comparisons_res2 = (less2_8 & ~eq_op) | (eq2_8 & leq_op) ? 8'hff : 0;
        simd8_min_res2 = less2_8? (fu_data_i.operand_a[23:16] & {8{min}}) | (fu_data_i.operand_b[23:16] & {8{~min}}) : (fu_data_i.operand_a[23:16] & {8{~min}}) | (fu_data_i.operand_b[23:16] & {8{min}});
               
        less1_8 = ($signed({simd_sgn & fu_data_i.operand_a[15], fu_data_i.operand_a[15:8]}) <
        $signed({simd_sgn & fu_data_i.operand_b[15], fu_data_i.operand_b[15:8]}));  
        eq1_8 = (fu_data_i.operand_a[15:8] == fu_data_i.operand_b[15:8]);
        simd8_comparisons_res1 = (less1_8 & ~eq_op) | (eq1_8 & leq_op) ? 8'hff : 0;
        simd8_min_res1 = less1_8? (fu_data_i.operand_a[15:8] & {8{min}}) | (fu_data_i.operand_b[15:8] & {8{~min}}) : (fu_data_i.operand_a[15:8] & {8{~min}}) | (fu_data_i.operand_b[15:8] & {8{min}});
        
        less0_8 = ($signed({simd_sgn & fu_data_i.operand_a[7], fu_data_i.operand_a[7:0]}) <
        $signed({simd_sgn & fu_data_i.operand_b[7], fu_data_i.operand_b[7:0]})); 
        eq0_8 = (fu_data_i.operand_a[7:0] == fu_data_i.operand_b[7:0]);
        simd8_comparisons_res0 = (less0_8 & ~eq_op) | (eq0_8 & leq_op) ? 8'hff : 0;
        simd8_min_res0 = less0_8? (fu_data_i.operand_a[7:0] & {8{min}}) | (fu_data_i.operand_b[7:0] & {8{~min}}) : (fu_data_i.operand_a[7:0] & {8{~min}}) | (fu_data_i.operand_b[7:0] & {8{min}});
        
        simd16_comparisons_result = {simd16_comparisons_res1, simd16_comparisons_res0};
        simd16_min_result = {simd16_min_res1, simd16_min_res0};
            
        simd8_comparisons_result = {simd8_comparisons_res3, simd8_comparisons_res2, simd8_comparisons_res1, simd8_comparisons_res0};
        simd8_min_result = {simd8_min_res3, simd8_min_res2, simd8_min_res1, simd8_min_res0};
       
    end 
    
    // ------------
    // SIMD Pack/Unpack instructions  
    // ------------
    
    logic [31:0]   simd_pkd_result; // SIMD Pack/Unpack final result 
    
    always_comb begin
        unique case (fu_data_i.operation)
          //SIMD 8 bits Unpack
            SUNPKD810, ZUNPKD810: simd_pkd_result = {{8{fu_data_i.operand_a[15] & sext}}, fu_data_i.operand_a[15:8], {8{fu_data_i.operand_a[7] & sext}}, fu_data_i.operand_a[7:0]};
            SUNPKD820, ZUNPKD820: simd_pkd_result = {{8{fu_data_i.operand_a[23] & sext}}, fu_data_i.operand_a[23:16], {8{fu_data_i.operand_a[7] & sext}}, fu_data_i.operand_a[7:0]};
            SUNPKD830, ZUNPKD830: simd_pkd_result = {{8{fu_data_i.operand_a[31] & sext}}, fu_data_i.operand_a[31:24], {8{fu_data_i.operand_a[7] & sext}}, fu_data_i.operand_a[7:0]};
            SUNPKD831, ZUNPKD831: simd_pkd_result = {{8{fu_data_i.operand_a[31] & sext}}, fu_data_i.operand_a[31:24], {8{fu_data_i.operand_a[15] & sext}}, fu_data_i.operand_a[15:8]};
            SUNPKD832, ZUNPKD832: simd_pkd_result = {{8{fu_data_i.operand_a[31] & sext}}, fu_data_i.operand_a[31:24], {8{fu_data_i.operand_a[23] & sext}}, fu_data_i.operand_a[23:16]};
          //SIMD 16 bits Pack
            PKBB16: simd_pkd_result = {fu_data_i.operand_a[15:0],fu_data_i.operand_b[15:0]};
            PKBT16: simd_pkd_result = {fu_data_i.operand_a[15:0],fu_data_i.operand_b[31:16]};
            PKTB16: simd_pkd_result = {fu_data_i.operand_a[31:16],fu_data_i.operand_b[15:0]};
            PKTT16: simd_pkd_result = {fu_data_i.operand_a[31:16],fu_data_i.operand_b[31:16]};
            default: ;
        endcase                             
    end 
    
    

    if (ariane_pkg::BITMANIP) begin : gen_bitmanip
        // Count Population + Count population Word

        popcount #(
        .INPUT_WIDTH(riscv::XLEN)
        ) i_cpop_count (
            .data_i    (operand_a_bitmanip),
            .popcount_o(cpop)
        );

        // Count Leading/Trailing Zeros
        // 64b
        lzc #(
        .WIDTH(riscv::XLEN),
        .MODE (1)
        ) i_clz_64b (
            .in_i(operand_a_bitmanip),
            .cnt_o(lz_tz_count),
            .empty_o(lz_tz_empty)
        );
        //32b
        lzc #(
        .WIDTH(32),
        .MODE (1)
        ) i_clz_32b (
            .in_i(operand_a_bitmanip[31:0]),
            .cnt_o(lz_tz_wcount),
            .empty_o(lz_tz_wempty)
        );
    end

    if (ariane_pkg::BITMANIP) begin : gen_orcbw_rev8w_results
        assign orcbw = {{8{|fu_data_i.operand_a[31:24]}}, {8{|fu_data_i.operand_a[23:16]}}, {8{|fu_data_i.operand_a[15:8]}}, {8{|fu_data_i.operand_a[7:0]}}};
        assign rev8w = {{fu_data_i.operand_a[7:0]}, {fu_data_i.operand_a[15:8]}, {fu_data_i.operand_a[23:16]}, {fu_data_i.operand_a[31:24]}};
        if (riscv::XLEN == 64) begin : gen_64b
            assign orcbw_result = {{8{|fu_data_i.operand_a[63:56]}}, {8{|fu_data_i.operand_a[55:48]}}, {8{|fu_data_i.operand_a[47:40]}}, {8{|fu_data_i.operand_a[39:32]}}, orcbw};
            assign rev8w_result = {rev8w , {fu_data_i.operand_a[39:32]}, {fu_data_i.operand_a[47:40]}, {fu_data_i.operand_a[55:48]}, {fu_data_i.operand_a[63:56]}};
        end else begin : gen_32b
            assign orcbw_result = orcbw;
            assign rev8w_result = rev8w;
        end
    end


    // -----------
    // Result MUX
    // -----------
    always_comb begin
        result_o = '0;
        unique case (fu_data_i.operation)
            // Standard Operations
            ANDL, ANDN: result_o = fu_data_i.operand_a & operand_b_neg[riscv::XLEN:1];
            ORL, ORN:   result_o = fu_data_i.operand_a | operand_b_neg[riscv::XLEN:1];
            XORL, XNOR: result_o = fu_data_i.operand_a ^ operand_b_neg[riscv::XLEN:1];

            // Adder Operations
            ADD, SUB, ADDUW, SH1ADD, SH2ADD, SH3ADD, SH1ADDUW, SH2ADDUW, SH3ADDUW:
            result_o = adder_result;
            // Add word: Ignore the upper bits and sign extend to 64 bit
            ADDW, SUBW: result_o = {{riscv::XLEN - 32{adder_result[31]}}, adder_result[31:0]};
            // Shift Operations
            SLL, SRL, SRA: result_o = (riscv::XLEN == 64) ? shift_result : shift_result32;
            // Shifts 32 bit
            SLLW, SRLW, SRAW: result_o = {{riscv::XLEN - 32{shift_result32[31]}}, shift_result32[31:0]};

            // Comparison Operations
            SLTS, SLTU: result_o = {{riscv::XLEN - 1{1'b0}}, less};

            // SIMD Adder Operations
            ADD16,SUB16,ADD8,SUB8, RADD8, RSUB8, RADD16, RSUB16, URADD8, URSUB8, URADD16, URSUB16, KADD16, UKADD16, KSUB16, UKSUB16, KADD8, UKADD8, KSUB8, UKSUB8, CRAS16, RCRAS16, URCRAS16, KCRAS16, UKCRAS16, CRSA16, RCRSA16, URCRSA16, KCRSA16, UKCRSA16, STAS16, RSTAS16, URSTAS16, KSTAS16, UKSTAS16, STSA16, RSTSA16, URSTSA16, KSTSA16, UKSTSA16:
            result_o = simd_adder_result;

            // SIMD 8 bits Shift Operations
            SRA8, SRA8_U, SRL8, SRL8_U, SLL8, KSLL8, KSLRA8, KSLRA8_U:
            result_o = simd_shift_result8;
            // SIMD 16 bits Shift Operations
            SRA16, SRA16_U, SRL16, SRL16_U, SLL16, KSLL16, KSLRA16, KSLRA16_U :
            result_o = simd_shift_result16;
            
            //SIMD 8 bits comparisons 
            CMPEQ8, SCMPLT8, SCMPLE8, UCMPLT8, UCMPLE8:
            result_o = simd8_comparisons_result;
            //SIMD 16 bits comparisons 
            CMPEQ16, SCMPLT16, SCMPLE16, UCMPLT16, UCMPLE16:
            result_o = simd16_comparisons_result;
            
            //SIMD 8 bits Maximum/minimum operations
            SMIN8, UMIN8, SMAX8, UMAX8 :
            result_o = simd8_min_result;
            //SIMD 16 bits Maximum/minimum operations
            SMIN16, UMIN16, SMAX16, UMAX16 :
            result_o = simd16_min_result;
            
            //SIMD Unpack 
            ZUNPKD810, ZUNPKD820, ZUNPKD830, ZUNPKD831, ZUNPKD832, SUNPKD810, SUNPKD820, SUNPKD830, SUNPKD831, SUNPKD832, PKBB16, PKBT16, PKTB16, PKTT16:
            result_o = simd_pkd_result;

            default: ; // default case to suppress unique warning
        endcase

        if (ariane_pkg::BITMANIP) begin
            // Index for Bitwise Rotation
            bit_indx = 1 << (fu_data_i.operand_b & (riscv::XLEN - 1));
            // rolw, roriw, rorw
            rolw = ({{riscv::XLEN-32{1'b0}},fu_data_i.operand_a[31:0]} << fu_data_i.operand_b[4:0]) | ({{riscv::XLEN-32{1'b0}},fu_data_i.operand_a[31:0]} >> (riscv::XLEN-32-fu_data_i.operand_b[4:0]));
            rorw = ({{riscv::XLEN-32{1'b0}},fu_data_i.operand_a[31:0]} >> fu_data_i.operand_b[4:0]) | ({{riscv::XLEN-32{1'b0}},fu_data_i.operand_a[31:0]} << (riscv::XLEN-32-fu_data_i.operand_b[4:0]));
            unique case (fu_data_i.operation)
                // Left Shift 32 bit unsigned
                SLLIUW:
                result_o = {{riscv::XLEN-32{1'b0}}, fu_data_i.operand_a[31:0]} << fu_data_i.operand_b[5:0];
                // Integer minimum/maximum
                MAX: result_o = less ? fu_data_i.operand_b : fu_data_i.operand_a;
                MAXU: result_o = less ? fu_data_i.operand_b : fu_data_i.operand_a;
                MIN: result_o = ~less ? fu_data_i.operand_b : fu_data_i.operand_a;
                MINU: result_o = ~less ? fu_data_i.operand_b : fu_data_i.operand_a;

                // Single bit instructions operations
                BCLR, BCLRI: result_o = fu_data_i.operand_a & ~bit_indx;
                BEXT, BEXTI: result_o = {{riscv::XLEN - 1{1'b0}}, |(fu_data_i.operand_a & bit_indx)};
                BINV, BINVI: result_o = fu_data_i.operand_a ^ bit_indx;
                BSET, BSETI: result_o = fu_data_i.operand_a | bit_indx;

                // Count Leading/Trailing Zeros
                CLZ, CTZ:
                result_o = (lz_tz_empty) ? ({{riscv::XLEN - $clog2(riscv::XLEN) {1'b0}}, lz_tz_count} + 1) :
                {{riscv::XLEN - $clog2(riscv::XLEN) {1'b0}}, lz_tz_count};
                CLZW, CTZW: result_o = (lz_tz_wempty) ? 32 : {{riscv::XLEN - 5{1'b0}}, lz_tz_wcount};

                // Count population
                CPOP, CPOPW: result_o = {{(riscv::XLEN - ($clog2(riscv::XLEN) + 1)) {1'b0}}, cpop};

                // Sign and Zero Extend
                SEXTB: result_o = {{riscv::XLEN - 8{fu_data_i.operand_a[7]}}, fu_data_i.operand_a[7:0]};
                SEXTH: result_o = {{riscv::XLEN - 16{fu_data_i.operand_a[15]}}, fu_data_i.operand_a[15:0]};
                ZEXTH: result_o = {{riscv::XLEN - 16{1'b0}}, fu_data_i.operand_a[15:0]};

                // Bitwise Rotation
                ROL:
                result_o = (riscv::XLEN == 64) ? ((fu_data_i.operand_a << fu_data_i.operand_b[5:0]) | (fu_data_i.operand_a >> (riscv::XLEN-fu_data_i.operand_b[5:0]))) : ((fu_data_i.operand_a << fu_data_i.operand_b[4:0]) | (fu_data_i.operand_a >> (riscv::XLEN-fu_data_i.operand_b[4:0])));
                ROLW: result_o = {{riscv::XLEN - 32{rolw[31]}}, rolw};
                ROR, RORI:
                result_o = (riscv::XLEN == 64) ? ((fu_data_i.operand_a >> fu_data_i.operand_b[5:0]) | (fu_data_i.operand_a << (riscv::XLEN-fu_data_i.operand_b[5:0]))) : ((fu_data_i.operand_a >> fu_data_i.operand_b[4:0]) | (fu_data_i.operand_a << (riscv::XLEN-fu_data_i.operand_b[4:0])));
                RORW, RORIW: result_o = {{riscv::XLEN - 32{rorw[31]}}, rorw};
                ORCB:
                result_o = orcbw_result;
                REV8:
                result_o = rev8w_result;

                default: ; // default case to suppress unique warning
            endcase
        end
        if (CVA6Cfg.ZiCondExtEn) begin
            unique case (fu_data_i.operation)
                CZERO_EQZ:
                result_o = (|fu_data_i.operand_b) ? fu_data_i.operand_a : '0; // move zero to rd if rs2 is equal to zero else rs1
                CZERO_NEZ:
                result_o = (|fu_data_i.operand_b) ? '0 : fu_data_i.operand_a; // move zero to rd if rs2 is nonzero else rs1
                default: ; // default case to suppress unique warning
            endcase
        end
    end
endmodule
