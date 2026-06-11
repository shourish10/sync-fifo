`include "design.sv"
// Testbench : sync_fifo

`timescale 1ns / 1ps

module tb_sync_fifo;


    // Parameters (match DUT)

    localparam DATA_WIDTH   = 8;
    localparam DEPTH        = 16;
    localparam CLK_PERIOD   = 10;   // 100 MHz


    // DUT signals
 
    reg                   clk;
    reg                   rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;
    wire                  almost_full;
    wire                  almost_empty;
    wire [$clog2(DEPTH):0] fill_level;


    // Instantiate DUT

    sync_fifo #(
        .DATA_WIDTH  (DATA_WIDTH),
        .DEPTH       (DEPTH)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (wr_en),
        .wr_data      (wr_data),
        .rd_en        (rd_en),
        .rd_data      (rd_data),
        .full         (full),
        .empty        (empty),
        .almost_full  (almost_full),
        .almost_empty (almost_empty),
        .fill_level   (fill_level)
    );

 
    // Clock generation

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;


    // Helper task: write one word

    task write_word(input [DATA_WIDTH-1:0] data);
        @(negedge clk);
        wr_en   = 1;
        wr_data = data;
        @(posedge clk);
        #1;
        wr_en   = 0;
    endtask


    // Helper task: read one word

    task read_word;
        @(negedge clk);
        rd_en = 1;
        @(posedge clk);
        #1;
        rd_en = 0;
    endtask

  
    // Reference model queue

    reg [DATA_WIDTH-1:0] ref_queue [0:DEPTH-1];
    integer q_head, q_tail, q_count;
    integer errors;


    // Stimulus

    integer i;

    initial begin
        // Initialise
        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        wr_data = 0;
        q_head  = 0;
        q_tail  = 0;
        q_count = 0;
        errors  = 0;

        // Apply reset for 5 cycles
        repeat(5) @(posedge clk);
        @(negedge clk);
        rst_n = 1;


        // TEST 1: Verify empty after reset

        @(posedge clk); #1;
        if (!empty)
            $display("FAIL T1: FIFO not empty after reset");
        else
            $display("PASS T1: FIFO empty after reset");


        // TEST 2: Write DEPTH words – check full

        for (i = 0; i < DEPTH; i = i + 1) begin
            write_word(i[DATA_WIDTH-1:0]);
            ref_queue[q_tail] = i[DATA_WIDTH-1:0];
            q_tail  = (q_tail + 1) % DEPTH;
            q_count = q_count + 1;
        end
        @(posedge clk); #1;
        if (!full)
            $display("FAIL T2: FIFO not full after %0d writes", DEPTH);
        else
            $display("PASS T2: FIFO full after %0d writes", DEPTH);


        // TEST 3: Write when full – should be ignored

        @(negedge clk);
        wr_en   = 1;
        wr_data = 8'hFF;
        @(posedge clk); #1;
        wr_en = 0;
        if (fill_level != DEPTH)
            $display("FAIL T3: Write to full FIFO accepted (fill=%0d)", fill_level);
        else
            $display("PASS T3: Write to full FIFO correctly ignored");


        // TEST 4: Read all DEPTH words – verify data & check empty

        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            rd_en = 1;
            @(posedge clk); #1;
            rd_en = 0;
            // rd_data is registered – valid the cycle after rd_en
            @(posedge clk); #1;
            if (rd_data !== ref_queue[q_head]) begin
                $display("FAIL T4[%0d]: expected %0h got %0h", i, ref_queue[q_head], rd_data);
                errors = errors + 1;
            end
            q_head  = (q_head + 1) % DEPTH;
            q_count = q_count - 1;
        end
        @(posedge clk); #1;
        if (!empty) begin
            $display("FAIL T4: FIFO not empty after all reads");
            errors = errors + 1;
        end else
            $display("PASS T4: Read-back data and empty flag correct");


        // TEST 5: Simultaneous read & write (no stall, fill stays constant)

        // Pre-fill halfway
        for (i = 0; i < DEPTH/2; i = i + 1)
            write_word(i[DATA_WIDTH-1:0]);

        repeat(20) begin : sim_rw
            @(negedge clk);
            wr_en   = 1;
            rd_en   = 1;
            wr_data = $random;
            @(posedge clk); #1;
            wr_en = 0;
            rd_en = 0;
        end
        $display("PASS T5: Simultaneous read/write ran without hang");


        // TEST 6: Read when empty – should be ignored

        // Drain first
        while (!empty) read_word;
        @(negedge clk);
        rd_en = 1;
        @(posedge clk); #1;
        rd_en = 0;
        if (fill_level != 0)
            $display("FAIL T6: Read from empty FIFO changed fill_level");
        else
            $display("PASS T6: Read from empty FIFO correctly ignored");

 
        // Summary

        if (errors == 0)
            $display("\n All sync_fifo tests PASSED \n");
        else
          $display("\n %0d sync_fifo test(s) FAILED \n", errors);

        $finish;
    end

    // Timeout watchdog

    initial begin
        #100000;
        $display("TIMEOUT: simulation exceeded 100 us");
        $finish;
    end


    // Waveform dump

    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, tb_sync_fifo);
    end

endmodule

