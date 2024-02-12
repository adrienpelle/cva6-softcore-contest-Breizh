`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/05/2024 06:34:55 PM
// Design Name: 
// Module Name: alu_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module alu_tb;
  import ariane_pkg::*;

  // Parameters
  localparam CLK_PERIOD = 10; // Clock period in nanoseconds

  // Signals
  logic clk;
  logic rst_ni;
  fu_data_t fu_data_i;
  riscv::xlen_t result_o;
  riscv::xlen_t temp_res;
  logic [7:0] res0_8b, res1_8b, res2_8b,res3_8b, opA0_8b,opA1_8b,opA2_8b,opA3_8b,opB0_8b,opB1_8b,opB2_8b,opB3_8b;
  logic [15:0] res0_16b, res1_16b, opA0_16b, opA1_16b, opB0_16b, opB1_16b;
  logic alu_branch_res_o;
  int n_test;
  
  //SIMD 8bits
  assign opA0_8b = fu_data_i.operand_a[7:0];
  assign opA1_8b = fu_data_i.operand_a[15:8];
  assign opA2_8b = fu_data_i.operand_a[23:16];
  assign opA3_8b = fu_data_i.operand_a[31:24];
  
  assign opB0_8b = fu_data_i.operand_b[7:0];
  assign opB1_8b = fu_data_i.operand_b[15:8];
  assign opB2_8b = fu_data_i.operand_b[23:16];
  assign opB3_8b = fu_data_i.operand_b[31:24];
  
  assign res0_8b = result_o[7:0];
  assign res1_8b = result_o[15:8];
  assign res2_8b = result_o[23:16];
  assign res3_8b = result_o[31:24];
  
  //SIMD 16bits
  assign opA0_16b = fu_data_i.operand_a[15:0];
  assign opA1_16b = fu_data_i.operand_a[31:16];
  
  assign opB0_16b = fu_data_i.operand_b[15:0];
  assign opB1_16b = fu_data_i.operand_b[31:16];
  
  assign res0_16b = result_o[15:0];
  assign res1_16b = result_o[31:16];

  // Instantiate ALU
  alu #(config_pkg::cva6_cfg_empty) uut (
    .clk_i(clk),
    .rst_ni(rst_ni),
    .fu_data_i(fu_data_i),
    .result_o(result_o),
    .alu_branch_res_o(alu_branch_res_o)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #((CLK_PERIOD / 2)) clk = ~clk;
  end

  // Test procedure
  initial begin
    // Initialize signals
    rst_ni = 1;
    fu_data_i = '0;
    n_test = 0;
    
    // Apply reset
    #10 rst_ni = 0;

    // Test Case 1: ADD operation
    n_test +=1;
    fu_data_i.operand_a = 32'h12345678;
    fu_data_i.operand_b = 32'h87654321;
    fu_data_i.operation = ADD;
    #10;
    if (result_o !== 32'h99999999) $fatal("Test Case 1 failed!");

    // Test Case 2: SUB operation
    n_test +=1;
    fu_data_i.operand_a = 32'h87654321;
    fu_data_i.operand_b = 32'h12345678;
    fu_data_i.operation = SUB;
    #10;
    if (result_o !== 32'h7530eca9) $fatal("Test Case 2 failed!");
    
    // Test Case 3: ADD16 operation
    n_test +=1;
    fu_data_i.operand_a = 32'b10101010101010101010101010101010;
    fu_data_i.operand_b = 32'b01010101010101010101010101010101;
    fu_data_i.operation = ADD16;
    #10;
    if (result_o !== 32'hffffffff) $fatal("Test Case 3 failed!");
    
    // Test Case 4: ADD16 operation
    n_test +=1;
    fu_data_i.operand_a = {16'hFFFF,16'hFFFE};
    fu_data_i.operand_b = {16'h0,16'hFFFF};
    fu_data_i.operation = ADD;
    #10;
    assign temp_res = result_o;
    fu_data_i.operand_a = {16'h0,16'hFFFE};
    fu_data_i.operand_b = {16'h0,16'hFF};
    fu_data_i.operation = ADD16;
    #10;
    if (result_o[15:0] !== temp_res[15:0] & result_o[31:16] !== temp_res[31:16]) $fatal("Test Case 4 failed!");

    
    // Test Case 5: SUB16 operation
    n_test +=1;
    fu_data_i.operand_a = {16'hFFFF,16'hFFFF};
    fu_data_i.operand_b = {16'h2,16'hFFFF};
    fu_data_i.operation = SUB16;
    if (result_o[15:0] !== 16'hFFFD & result_o[31:16] !== 16'h0) $fatal("Test Case 5 failed!");
    #10;
    
    // Test Case 6: ADD8 operation
    n_test +=1;
    fu_data_i.operand_a = {8'b10101010,8'b00000010,8'b00000000,8'b11111111};
    fu_data_i.operand_b = {8'b10101010,8'b00000011,8'b00000000,8'b11111111};
    fu_data_i.operation = ADD8;
    #10;
    if (result_o !== {8'b01010100,8'b0000101,8'b00000000,8'b11111110}) $fatal("Test Case 6 failed!");
    
    // Test Case 7: SUB8 operation
    n_test +=1;
    fu_data_i.operand_a = {8'b10101010,8'b00000010,8'b00000000,8'b11111111};
    fu_data_i.operand_b = {8'b10101010,8'b00000011,8'b00000000,8'b11111111};
    fu_data_i.operation = SUB8;
    #10;
    if (result_o !== {8'b00000000,8'b11111111,8'b00000000,8'b00000000}) $fatal("Test Case 7 failed!");
    
    // Test Case 8: ADD operations
    n_test +=1;
    fu_data_i.operand_a = {8'b00000000,8'b00000000,8'b00000000,8'b00000111};
    fu_data_i.operand_b = {8'b00000000,8'b00000000,8'b00000000,8'b00000100};
    fu_data_i.operation = ADD;
    #10;
    if (result_o !== 32'd11) $fatal("Test Case 8a failed!");
    fu_data_i.operation = ADD8;
    #10;
    if (result_o !== {8'b00000000,8'b00000000,8'b00000000,8'b00001011}) $fatal("Test Case 8b failed!");
    fu_data_i.operation = ADD16;
    #10;
    if (result_o !== {8'b00000000,8'b00000000,8'b00000000,8'b00001011}) $fatal("Test Case 8c failed!");
    
    //if (result_o !== 32'h7530869) $fatal("Test Case 3 failed!");

    // Test Case 9: SUB operation
    n_test +=1;
    fu_data_i.operand_a = 32'd20;
    fu_data_i.operand_b = 32'd35;
    fu_data_i.operation = SUB;
    #10;
    if (result_o !== {8'b11111111,8'b11111111,8'b11111111,8'b11110001}) $fatal("Test Case 9a failed!");
    fu_data_i.operand_a = 32'd20;
    fu_data_i.operand_b = 32'd35;
    fu_data_i.operation = SUB8;
    #10;
    if (result_o !== {8'b00000000,8'b00000000,8'b00000000,8'b11110001}) $fatal("Test Case 9b failed!");
    fu_data_i.operand_a = 32'd20;
    fu_data_i.operand_b = 32'd35;
    fu_data_i.operation = SUB16;
    #10;
    if (result_o !== {8'b00000000,8'b00000000,8'b11111111,8'b11110001}) $fatal("Test Case 9c failed!");

      // Test Case 10: RADD8 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b01000111,8'b00101110,8'b00001100};
      fu_data_i.operand_b = {8'b11111111,8'b10111001,8'b00010001,8'b11100010};
      fu_data_i.operation = RADD8;
      #10;
      if (result_o !== {8'hFF,8'h00,8'h1F,8'hF7}) $fatal("Test Case 10 failed");  
      
      // Test Case 11: RSUB8 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b01000111,8'b00101110,8'b00001100};
      fu_data_i.operand_b = {8'b11111111,8'b10111001,8'b00010001,8'b11100010};
      fu_data_i.operation = RSUB8;
      #10;
      if (result_o !== {8'h00,8'h47,8'h0E,8'h15}) $fatal("Test Case 11 failed");    
      
      // Test Case 12: URADD8 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b01000111,8'b00101110,8'b00001100};
      fu_data_i.operand_b = {8'b11111111,8'b10111001,8'b00010001,8'b11100010};
      fu_data_i.operation = URADD8;
      #10;
      if (result_o !== {8'hFF,8'h80,8'h1F,8'h77}) $fatal("Test Case 12 failed!");
           
           
      // Test Case 13: URSUB8 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b00100111,8'b00101110,8'b10001100};
      fu_data_i.operand_b = {8'b11111111,8'b00001001,8'b00010001,8'b00000010};
      fu_data_i.operation = URSUB8;
      #10;
      if (result_o !== {8'h00,8'h0F,8'h0E,8'h45}) $fatal("Test Case 13 failed!");      
      
      // Test Case 14: RADD16 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
      fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b00010001,8'b11100010};
      fu_data_i.operation = RADD16;
      #10;
      if (result_o !== {16'hFFFF,16'h1FF7}) $fatal("Test Case 14 failed!"); 
           
      // Test Case 15: RSUB16 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
      fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b00010001,8'b11100010};
      fu_data_i.operation = RSUB16;
      #10;
       if (result_o !== {16'h0000,16'h0E15}) $fatal("Test Case 15 failed!"); 
      
      // Test Case 16: URADD16 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
      fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b00010001,8'b11100010};
      fu_data_i.operation = URADD16;
      #10;
      if (result_o !== {16'hFFFF,16'h1FF7}) $fatal("Test Case 16 failed!");    
           
      // Test Case 17: URSUB16 operation
      n_test +=1;
      fu_data_i.operand_a = {8'b11111111,8'b00100111,8'b00101110,8'b10001100};
      fu_data_i.operand_b = {8'b11111111,8'b00001001,8'b00010001,8'b00000010};
      fu_data_i.operation = URSUB16;
      #10;
      if (result_o !== {16'h000F,16'h0EC5}) $fatal("Test Case 17 failed!"); 

    // Test Case 18: ADD8 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'hFF;
    fu_data_i.operand_b = 32'h01;
    fu_data_i.operation = ADD8;
    #10;
    if (result_o !== 32'h00) $fatal("Test Case 18 failed!");
    
    // Test Case 19: SUB8 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01;
    fu_data_i.operand_b = 32'h02;
    fu_data_i.operation = SUB8;
    #10;
    if (result_o !== 32'hFF) $fatal("Test Case 19 failed!");
    
    // Test Case 20: RADD8 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'hFE;
    fu_data_i.operand_b = 32'h01;
    fu_data_i.operation = RADD8;
    #10;
    if (result_o !== 32'hFF) $fatal("Test Case 20 failed");
    
    // Test Case 21: ADD16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'hFFFF;
    fu_data_i.operand_b = 32'h0001;
    fu_data_i.operation = ADD16;
    #10;
    if (result_o !== 32'h0000) $fatal("Test Case 21 failed!");
    
    // Test Case 22: SUB16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h0001;
    fu_data_i.operand_b = 32'h0002;
    fu_data_i.operation = SUB16;
    #10;
    if (result_o !== 32'hFFFF) $fatal("Test Case 22 failed!");
    
    // Test Case 23: RADD16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h0001;
    fu_data_i.operand_b = 32'h0001;
    fu_data_i.operation = RADD16;
    #10;
    if (result_o !== 32'h0001) $fatal("Test Case 23 failed");
    
    // Test Case 24: UKADD8 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2E0FF;
    fu_data_i.operand_b = 32'hFF2301F1;
    fu_data_i.operation = UKADD8;
    #10;
    if (result_o !== 32'hffffe1ff) $fatal("Test Case 24 failed!");
    
    // Test Case 25: UKSUB8 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2E008;
    fu_data_i.operand_b = 32'hFF02F01E2;
    fu_data_i.operation = UKSUB8;
    #10;
    if (result_o !== 32'h00b3df00) $fatal("Test Case 25 failed!");
    
    // Test Case 26: UKADD16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2FFFF;
    fu_data_i.operand_b = 32'hFF020EF1;
    fu_data_i.operation = UKADD16;
    #10;
    if (result_o !== 32'hffffffff) $fatal("Test Case 26 failed!");
    
    // Test Case 27: UKSUB16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'hFF0202E2;
    fu_data_i.operand_b = 32'h00010041;
    fu_data_i.operation = UKSUB16;
    #10;
    if (result_o !== 32'hff0102a1) $fatal("Test Case 27 failed!");
    
    // Test Case 28: KADD8 saturée
    n_test += 1;
    fu_data_i.operand_a = {8'b01111111,8'b01111111,8'b10000000,8'b10001000};
    fu_data_i.operand_b = {8'b01111111,8'b01111111,8'b00010001,8'b10000010};
    fu_data_i.operation = KADD8;
    #10;
    if (result_o !== 32'h7f7f9180) $fatal("Test Case 28 failed!");
    
    // Test Case 29: KSUB8 saturée
    n_test += 1;
    fu_data_i.operand_a = {8'b00000111,8'b11111111,8'b01111110,8'b10001100};
    fu_data_i.operand_b = {8'b01111111,8'b01111111,8'b10000001,8'b00000010};
    fu_data_i.operation = KSUB8;
    #10;
    if (result_o !== 32'h88807f8a) $fatal("Test Case 29 failed!");
    
    // Test Case 30: KADD16 saturée
    n_test += 1;
    fu_data_i.operand_a = {8'b01000000,8'b00000000,8'b10000000,8'b00000000};
    fu_data_i.operand_b = {8'b01111111,8'b11111111,8'b11111111,8'b11111111};
    fu_data_i.operation = KADD16;
    #10;
    if (result_o !== 32'h7fff8000) $fatal("Test Case 30 failed!");
    
    // Test Case 31: KSUB16 saturée
    n_test += 1;
    fu_data_i.operand_a = {8'b10000000,8'b00000000,8'b01111111,8'b11111111};
    fu_data_i.operand_b = {8'b00000000,8'b00011111,8'b11111111,8'b00000000};
    fu_data_i.operation = KSUB16;
    #10;
    if (result_o !== 32'h80007fff) $fatal("Test Case 31 failed!");
    
        
    // Test Case 32: CRAS16  saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h0001;
    fu_data_i.operand_b = 32'h0001;
    fu_data_i.operation = CRAS16;
    #10;
    //if (result_o !== 32'h0001) $fatal("Test Case 23 failed");
    
    // Test Case 33: RCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h0001;
    fu_data_i.operand_b = 32'h0001;
    fu_data_i.operation = RCRAS16;
    #10;
    //if (result_o !== 32'h0001) $fatal("Test Case 23 failed");
    
    // Test Case 34: URCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2FFFF;
    fu_data_i.operand_b = 32'hFF020EF1;
    fu_data_i.operation = URCRAS16;
    #10;
   // if (result_o !== 32'hffffffff) $fatal("Test Case 26 failed!"); 
    
    // Test Case 35: KCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h0001;
    fu_data_i.operand_b = 32'h0001;
    fu_data_i.operation = KCRAS16;
    #10;
    //if (result_o !== 32'h0001) $fatal("Test Case 23 failed");  
    
     // Test Case 36: UKCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'hFFFF01E2;
    fu_data_i.operand_b = 32'h0EF1FF02;
    fu_data_i.operation = UKCRAS16;
    #10;
   // if (result_o !== 32'hffffffff) $fatal("Test Case 26 failed!");   

    
    
      
 
    // Add more test cases as needed...

    // Finish simulation
    $finish;
  end

endmodule