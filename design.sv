
// Synchronous FIFO

// Architecture : Single-clock, dual-pointer, extra-bit full/empty disambiguation
// Parameters   : DATA_WIDTH, DEPTH (must be power-of-2)
// Features     : almost_full / almost_empty flags, fill-level output


`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH  = 8,
    parameter DEPTH       = 16,          // Must be a power of 2
    parameter AFULL_THRESH  = DEPTH - 2, // almost_full  threshold
    parameter AEMPTY_THRESH = 2          // almost_empty threshold
)(
    input  wire                  clk,
    input  wire                  rst_n,      // Active-low synchronous reset

    // Write port
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,

    // Read port
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,

    // Status flags
    output wire                  full,
    output wire                  empty,
    output wire                  almost_full,
    output wire                  almost_empty,
    output wire [$clog2(DEPTH):0] fill_level   // 0 .. DEPTH
);

   
    // Local parameters
 
    localparam PTR_WIDTH = $clog2(DEPTH);   // e.g. 4 for DEPTH=16

   
    // Internal signals

    // One extra bit in the pointers for full/empty disambiguation
    reg [PTR_WIDTH:0] wr_ptr;   // write pointer  (MSB = wrap bit)
    reg [PTR_WIDTH:0] rd_ptr;   // read  pointer  (MSB = wrap bit)

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Convenience aliases – lower PTR_WIDTH bits address the memory
    wire [PTR_WIDTH-1:0] wr_addr = wr_ptr[PTR_WIDTH-1:0];
    wire [PTR_WIDTH-1:0] rd_addr = rd_ptr[PTR_WIDTH-1:0];

   
    // Status flag logic
    // Full  : same address bits, different wrap bits
    // Empty : pointers are identical (both bits)
  
    assign full        = (wr_ptr == {~rd_ptr[PTR_WIDTH], rd_ptr[PTR_WIDTH-1:0]});
    assign empty       = (wr_ptr == rd_ptr);

    assign fill_level  = wr_ptr - rd_ptr;           // wraps correctly
    assign almost_full  = (fill_level >= AFULL_THRESH);
    assign almost_empty = (fill_level <= AEMPTY_THRESH);

 
    // Write logic

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= {(PTR_WIDTH+1){1'b0}};
        end else if (wr_en && !full) begin
            mem[wr_addr] <= wr_data;
            wr_ptr       <= wr_ptr + 1'b1;
        end
    end

   
    // Read logic  (registered output for better timing)
   
    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr  <= {(PTR_WIDTH+1){1'b0}};
            rd_data <= {DATA_WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_addr];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

endmodule
