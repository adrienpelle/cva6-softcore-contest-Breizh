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
    fu_data_i.operand_a = 32'hFF020EF1;
    fu_data_i.operand_b = 32'h01E2FFFF;
    fu_data_i.operation = CRAS16;
    #10;
    if (result_o !== 32'hff010d0f) $fatal("Test Case 32 failed");
    
    // Test Case 33: RCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2FFFF;
    fu_data_i.operand_b = 32'hFF020EF1;
    fu_data_i.operation = RCRAS16;
    #10;
    if (result_o !== 32'h0869007e) $fatal("Test Case 33 failed");
    
    // Test Case 34: URCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2FFFF;
    fu_data_i.operand_b = 32'hFF020EF1;
    fu_data_i.operation = URCRAS16;
    #10;
    if (result_o !== 32'h0869007e) $fatal("Test Case 34 failed!"); 
    
    // Test Case 35: KCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = {8'b01111111,8'b11111111,8'b10000000,8'b00000000};
    fu_data_i.operand_b = {8'b01000000,8'b11111111,8'b01111111,8'b00000000};
    fu_data_i.operation = KCRAS16;
    #10;
    if (result_o !== 32'h7fff8000) $fatal("Test Case 35 failed");  
    
     // Test Case 36: UKCRAS16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'hFFFF01E2;
    fu_data_i.operand_b = 32'h0EF1FF02;
    fu_data_i.operation = UKCRAS16;
    #10;
    if (result_o !== 32'hffff0000) $fatal("Test Case 36 failed!");     
   
   // Test Case 37: CRSA16  saturée
    n_test += 1;
    fu_data_i.operand_a = 32'hFF020EF1;
    fu_data_i.operand_b = 32'h01E2FFFF;
    fu_data_i.operation = CRSA16;
    #10;
    if (result_o !== 32'hff0310d3) $fatal("Test Case 37 failed");
    
    // Test Case 38: RCRSA16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2FFFF;
    fu_data_i.operand_b = 32'hFF020EF1;
    fu_data_i.operation = RCRSA16;
    #10;
    if (result_o !== 32'hf978ff80) $fatal("Test Case 38 failed");
    
    // Test Case 39: URCRSA16 saturée
    n_test += 1;
    fu_data_i.operand_a = 32'h01E2FFFF;
    fu_data_i.operand_b = 32'hFF020EF1;
    fu_data_i.operation = URCRSA16;
    #10;
    if (result_o !== 32'hf978ff80) $fatal("Test Case 39 failed!"); 
    
    // Test Case 40: KCRSA16 saturée
    n_test += 1;
    fu_data_i.operand_a = {8'b10000000,8'b00000000,8'b01111111,8'b11111111};
    fu_data_i.operand_b = {8'b01111111,8'b00000000, 8'b01000000,8'b11111111};
    fu_data_i.operation = KCRSA16;
    #10;
    if (result_o !== 32'h80007fff) $fatal("Test Case 40 failed");  
    
     // Test Case 41: UKCRSA16 saturée
    n_test += 1;
    fu_data_i.operand_a = {8'b10000000,8'b00000000,8'b01111111,8'b11111111};
    fu_data_i.operand_b = {8'b01111111,8'b00000000, 8'b01000000,8'b11111111};
    fu_data_i.operation = UKCRSA16;
    #10;
    if (result_o !== 32'h3f01feff) $fatal("Test Case 41 failed!");      
    
    // Test Case 42: STAS16  saturée                                           
 n_test += 1;                                                               
 fu_data_i.operand_a = 32'hFF020EF1;                                        
 fu_data_i.operand_b = 32'h01E2FFFF;                                        
 fu_data_i.operation = STAS16;                                              
 #10;                                                                       
 if (result_o !== 32'h00e40ef2) $fatal("Test Case 42 failed");              
                                                                            
 // Test Case 43: RSTAS16 saturée                                           
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b10000001,8'b00000000,8'b10000000,8'b00000000};   
 fu_data_i.operand_b = {8'b01111111,8'b00000000, 8'b01110000,8'b11111111};  
 fu_data_i.operation = RSTAS16;                                             
 #10;                                                                       
 if (result_o !== 32'h00008780) $fatal("Test Case 43 failed");              
                                                                            
 // Test Case 44: URSTAS16 saturée                                          
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b10000000,8'b00000000,8'b11111111,8'b11111111};   
 fu_data_i.operand_b = {8'b11111111,8'b00000000, 8'b11000000,8'b11111111};  
 fu_data_i.operation = URSTAS16;                                            
 #10;                                                                       
 if (result_o !== 32'hbf801f80) $fatal("Test Case 44 failed!");             
                                                                            
 // Test Case 45: KSTAS16 saturée                                           
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b01110000,8'b00000000,8'b10000000,8'b00011111};   
 fu_data_i.operand_b = {8'b01111111,8'b00000000, 8'b01000000,8'b11111111};  
 fu_data_i.operation = KSTAS16;                                             
 #10;                                                                       
 if (result_o !== 32'h7fff8000) $fatal("Test Case 45 failed");              
                                                                            
  // Test Case 46: UKSTAS16 saturée                                         
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100000,8'b00000000,8'b00000000,8'b11111111};   
 fu_data_i.operand_b = {8'b11111111,8'b00000000, 8'b01000000,8'b11111111};  
 fu_data_i.operation = UKSTAS16;                                            
 #10;                                                                       
 if (result_o !== 32'hffff0000) $fatal("Test Case 46 failed!");              
 
 // Test Case 47: STSA16  saturée                                           
 n_test += 1;                                                               
 fu_data_i.operand_a = 32'hFF020EF1;                                        
 fu_data_i.operand_b = 32'h01E2FFFF;                                        
 fu_data_i.operation = STSA16;                                              
 #10;                                                                       
 if (result_o !== 32'hfd200ef0) $fatal("Test Case 47 failed");              
                                                                            
 // Test Case 48: RSTSA16 saturée                                           
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b10000001,8'b00000000,8'b10000000,8'b00000000};   
 fu_data_i.operand_b = {8'b01111111,8'b00000000, 8'b01110000,8'b11111111};  
 fu_data_i.operation = RSTSA16;                                             
 #10;                                                                       
 if (result_o !== 32'h8100f87f) $fatal("Test Case 48 failed");              
                                                                            
 // Test Case 49: URSTSA16 saturée                                          
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b10000000,8'b00000000,8'b11111111,8'b11111111};   
 fu_data_i.operand_b = {8'b11111111,8'b00000000, 8'b11000000,8'b11111111};  
 fu_data_i.operation = URSTSA16;                                            
 #10;                                                                       
 if (result_o !== 32'hc080e07f) $fatal("Test Case 49 failed!");             
                                                                            
 // Test Case 50: KSTSA16 saturée                                           
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b01110000,8'b00000000,8'b10000000,8'b00011111};   
 fu_data_i.operand_b = {8'b01111111,8'b00000000, 8'b01000000,8'b11111111};  
 fu_data_i.operation = KSTSA16;                                             
 #10;                                                                       
 if (result_o !== 32'hf100c11e) $fatal("Test Case 50 failed");              
                                                                            
  // Test Case 51: UKSTSA16 saturée                                         
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100000,8'b00000000,8'b00000000,8'b11111111};   
 fu_data_i.operand_b = {8'b11111111,8'b00000000, 8'b01000000,8'b11111111};  
 fu_data_i.operation = UKSTSA16;                                            
 #10;                                                                       
 if (result_o !== 32'h000041fe) $fatal("Test Case 51 failed!");    
 
 // Test Case 52: SRA8                                        
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100011,8'b00000000,8'b00000001,8'b11100101};   
 fu_data_i.operand_b = 32'd1;  
 fu_data_i.operation = SRA8;                                            
 #10;                                            
 if (result_o !== 32'hf10000f2) $fatal("Test Case 52 failed!");     
 
 // Test Case 53: SRL8                                        
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100000,8'b00000011,8'b00000001,8'b11111111};   
 fu_data_i.operand_b = 32'd2;  
 fu_data_i.operation = SRL8;                                              
 #10;                                                                           
 if (result_o !== 32'h3800003f) $fatal("Test Case 53 failed!"); 
 
 
 // Test Case 54: SLL8                                        
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100001,8'b00000011,8'b00000001,8'b11111111};   
 fu_data_i.operand_b = 32'd7;  
 fu_data_i.operation = SLL8;                                            
 #10;                                                                         
 if (result_o !== 32'h80808080) $fatal("Test Case 54 failed!");             
 
 // Test Case 55: SRA16                                        
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100011,8'b00000000,8'b00000001,8'b11100101};   
 fu_data_i.operand_b = 32'd5;  
 fu_data_i.operation = SRA16;                                            
 #10;                                                                       
 if (result_o !== 32'hff18000f) $fatal("Test Case 55 failed!");     
 
 // Test Case 56: SRL16                                        
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100000,8'b00000011,8'b00000001,8'b11111111};   
 fu_data_i.operand_b = 32'd4;  
 fu_data_i.operation = SRL16;                                            
 #10;                                                                                                     
 if (result_o !== 32'h0e00001f) $fatal("Test Case 56 failed!"); 
 
 
 // Test Case 57: SLL16                                        
 n_test += 1;                                                               
 fu_data_i.operand_a = {8'b11100001,8'b00000011,8'b00000001,8'b11111111};   
 fu_data_i.operand_b = 32'd6;  
 fu_data_i.operation = SLL16;                                            
 #10;                                                                                               
 if (result_o !== 32'h40c07fc0) $fatal("Test Case 57 failed!");   
         
// Test Case 58: CMPEQ16 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b00010001,8'b11100010};
fu_data_i.operation = CMPEQ16;
#10;
if (result_o !== {16'hFFFF,16'h0000}) $fatal("Test Case 58 failed!");    

// Test Case 59: SCMPLT16 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b11010001,8'b11100010};
fu_data_i.operation = SCMPLT16;
#10;
if (result_o !== {16'h0000,16'hFFFF}) $fatal("Test Case 59 failed!");    

// Test Case 60: SCMPLE16 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b11010001,8'b11100010};
fu_data_i.operation = SCMPLE16;
#10;
if (result_o !== {16'hFFFF,16'hFFFF}) $fatal("Test Case 60 failed!");    

// Test Case 61: SCMPLE16 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b11010001,8'b11100010};
fu_data_i.operation = SCMPLE16;
#10;
if (result_o !== {16'hFFFF,16'h0000}) $fatal("Test Case 61 failed!");    

// Test Case 62: UCMPLT16 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b11010001,8'b11100010};
fu_data_i.operation = UCMPLT16;
#10;
if (result_o !== {16'h0000,16'hFFFF}) $fatal("Test Case 62 failed!");    
    
// Test Case 63: UCMPLE16 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b11010001,8'b11100010};
fu_data_i.operation = UCMPLE16;
#10;
if (result_o !== {16'hFFFF,16'hFFFF}) $fatal("Test Case 63 failed!");    

// Test Case 64: CMPEQ8 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b10011101,8'b00000000};
fu_data_i.operand_b = {8'b11111111,8'b01111111,8'b10011101,8'b00000001};
fu_data_i.operation = CMPEQ8;
#10;
if (result_o !== {32'hFF00FF00}) $fatal("Test Case 64 failed!");    

// Test Case 65: SCMPLT8 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b10111111,8'b00010001,8'b01100010};
fu_data_i.operation = SCMPLT8;
#10;
if (result_o !== 32'h000000FF) $fatal("Test Case 65 failed!");    

// Test Case 66: SCMPLE8 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b01111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b00010001,8'b00001100};
fu_data_i.operation = SCMPLE8;
#10;
if (result_o !== 32'hFF0000FF) $fatal("Test Case 66 failed!");    

// Test Case 67: SCMPLE8 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b11010001,8'b11100010};
fu_data_i.operation = SCMPLE8;
#10;
if (result_o !== 32'hFFFF0000) $fatal("Test Case 67 failed!");    

// Test Case 68: UCMPLT8 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b10111111,8'b00010001,8'b01100010};
fu_data_i.operation = UCMPLT8;
#10;
if (result_o !== 32'h000000FF) $fatal("Test Case 68 failed!");    
    
// Test Case 69: UCMPLE8 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b10111111,8'b00010001,8'b01100010};
fu_data_i.operation = UCMPLE8;
#10;
if (result_o !== 32'hFF0000FF) $fatal("Test Case 69 failed!");   

// Test Case 70: SMIN16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b00000000,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b01010001,8'b11100010};
fu_data_i.operation = SMIN16;
#10;
if (result_o !== 32'hffffae0c) $fatal("Test Case 70 failed!");    
  

// Test Case 71: UMIN16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b00000000,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b01010001,8'b11100010};
fu_data_i.operation = UMIN16;
#10;
if (result_o !== 32'h000051e2) $fatal("Test Case 71 failed!");   

// Test Case 72: SMAX16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b11111111,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b01010001,8'b11100010};
fu_data_i.operation = SMAX16;
#10;
if (result_o !== 32'h00ff51e2) $fatal("Test Case 72 failed!");  
  

// Test Case 73: UMAX16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b11111111,8'b10101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b11111111,8'b01010001,8'b11100010};
fu_data_i.operation = UMAX16;
#10;
if (result_o !== 32'hffffae0c) $fatal("Test Case 73 failed!");  
    

// Test Case 74: SMIN8 operation
n_test +=1;
fu_data_i.operand_a = {8'b01111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = SMIN8;
#10;
if (result_o !== 32'hffff910c) $fatal("Test Case 74 failed!");  



// Test Case 75: UMIN8 operation
n_test +=1;
fu_data_i.operand_a = {8'b01111111,8'b11111111,8'b00101110,8'b00001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = UMIN8;
#10;
if (result_o !== 32'h7f3f2e0c) $fatal("Test Case 75 failed!");    

// Test Case 76: SMAX8 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = SMAX8;
#10;
if (result_o !== 32'h003f2e62) $fatal("Test Case 76 failed!");  



// Test Case 77: UMAX8 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = UMAX8;
#10;
if (result_o !== 32'hff9f918c) $fatal("Test Case 77 failed!");   

// Test Case 78: SUNPKD810 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = SUNPKD810;
#10;
if (result_o !== 32'h002eff8c) $fatal("Test Case 78 failed!");   

// Test Case 79: ZUNPKD810 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = ZUNPKD810;
#10;
if (result_o !== 32'h002e008c) $fatal("Test Case 79 failed!");   

// Test Case 80: SUNPKD820 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = SUNPKD820;
#10;
if (result_o !== 32'hff9fff8c) $fatal("Test Case 80 failed!");   

// Test Case 81: ZUNPKD820 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = ZUNPKD820;
#10;
if (result_o !== 32'h009f008c) $fatal("Test Case 81 failed!"); 

// Test Case 82: SUNPKD830 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = SUNPKD830;
#10;
if (result_o !== 32'h0000ff8c) $fatal("Test Case 82 failed!");   

// Test Case 83: ZUNPKD830 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = ZUNPKD830;
#10;
if (result_o !== 32'h0000008c) $fatal("Test Case 83 failed!");   
    
// Test Case 84: SUNPKD831 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = SUNPKD831;
#10;
if (result_o !== 32'h0000002e) $fatal("Test Case 84 failed!");   

// Test Case 85: ZUNPKD830 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = ZUNPKD831;
#10;
if (result_o !== 32'h0000002e) $fatal("Test Case 85 failed!");   

// Test Case 86: SUNPKD832 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = SUNPKD832;
#10;
if (result_o !== 32'h0000ff9f) $fatal("Test Case 86 failed!");   

// Test Case 87: ZUNPKD832 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = ZUNPKD832;
#10;
if (result_o !== 32'h0000009f) $fatal("Test Case 87 failed!");

// Test Case 88: PKBB16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = PKBB16;
#10;
if (result_o !== 32'h2e8c9162) $fatal("Test Case 88 failed!");     

// Test Case 89: PKBT16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = PKBT16;
#10;
if (result_o !== 32'h2e8cff3f) $fatal("Test Case 89 failed!");    

// Test Case 90: PKTB16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = PKTB16;
#10;
if (result_o !== 32'h009f9162) $fatal("Test Case 90 failed!");  

// Test Case 91: PKTT16 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b10011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {8'b11111111,8'b00111111,8'b10010001,8'b01100010};
fu_data_i.operation = PKTT16;
#10;
if (result_o !== 32'h009fff3f) $fatal("Test Case 91 failed!"); 

// Test Case 92: SCLIP32 operation
n_test +=1;
fu_data_i.operand_a = {8'b10000000,8'b00011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {5'd5};
fu_data_i.operation = SCLIP32;
#10;
if (result_o !== 32'hffffffe0) $fatal("Test Case 92 failed!");    

// Test Case 93: UCLIP32 operation
n_test +=1;
fu_data_i.operand_a = {8'b10000000,8'b00011111,8'b00101110,8'b10001100};
fu_data_i.operand_b = {5'd15};
fu_data_i.operation = UCLIP32;
#10;
if (result_o !== 32'h0) $fatal("Test Case 93 failed!");       
    
// Test Case 94: SCLIP32 operation
n_test +=1;
fu_data_i.operand_a = {8'b11111111,8'b11111111,8'b11111111,8'b11111111};
fu_data_i.operand_b = {5'b11111};
fu_data_i.operation = SCLIP32;
#10;
if (result_o !== 32'hffffffff) $fatal("Test Case 94 failed!");  

// Test Case 95: UCLIP32 operation
n_test +=1;
fu_data_i.operation = UCLIP32;
#10;
if (result_o !== 32'h0) $fatal("Test Case 95 failed!"); 

// Test Case 96: SCLIP32 operation
n_test +=1;
fu_data_i.operand_a = {8'b00000000,8'b11111111,8'b11111111,8'b11111111};
fu_data_i.operand_b = {5'd6};
fu_data_i.operation = SCLIP32;
#10;
if (result_o !== 32'h0000003f) $fatal("Test Case 96 failed!");  

// Test Case 97: SCLIP32 operation
n_test +=1;
fu_data_i.operand_a = {8'b10000000,8'b00000000,8'b00000000,8'b00000000};
fu_data_i.operation = SCLIP32;
#10;
if (result_o !== 32'hffffffc0) $fatal("Test Case 97 failed!");    
      
 
    // Add more test cases as needed...

    // Finish simulation
    $finish;
  end

endmodule