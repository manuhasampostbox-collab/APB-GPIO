// -----------------------------------------------------------------------------
// tb_apb_gpio.v
// Self-checking testbench for apb_gpio. Drives standard APB
// setup-then-access write/read transactions and checks:
//   1. DIR and DATA_OUT registers read back what was written
//   2. gpio_out reflects DATA_OUT
//   3. DATA_IN register reflects the gpio_in input
//   4. INT_STATUS latches a change on gpio_in, and write-1-to-clear works
//   5. Writing to the read-only DATA_IN register asserts PSLVERR
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_apb_gpio;

    reg         pclk;
    reg         presetn;
    reg         psel, penable, pwrite;
    reg  [3:0]  paddr;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready;
    wire        pslverr;

    reg  [7:0]  gpio_in;
    wire [7:0]  gpio_out;
    wire [7:0]  gpio_dir;

    integer     pass_count;
    integer     fail_count;

    always #5 pclk = ~pclk;

    apb_gpio dut (
        .pclk     (pclk),
        .presetn  (presetn),
        .psel     (psel),
        .penable  (penable),
        .pwrite   (pwrite),
        .paddr    (paddr),
        .pwdata   (pwdata),
        .prdata   (prdata),
        .pready   (pready),
        .pslverr  (pslverr),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_dir (gpio_dir)
    );

    task apb_write(input [3:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            psel    <= 1'b1;
            penable <= 1'b0;
            pwrite  <= 1'b1;
            paddr   <= addr;
            pwdata  <= data;
            @(posedge pclk);
            penable <= 1'b1;
            @(posedge pclk);        // PREADY is tied high, so access completes here
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
        end
    endtask

    task apb_read(input [3:0] addr, output [31:0] data);
        begin
            @(posedge pclk);
            psel    <= 1'b1;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            paddr   <= addr;
            @(posedge pclk);
            penable <= 1'b1;
            @(posedge pclk);
            data = prdata;
            psel    <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    task check(input [319:0] name, input [31:0] got, input [31:0] expected);
        begin
            if (got === expected) begin
                $display("[PASS] %0s: got 0x%08h", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s: expected 0x%08h, got 0x%08h", name, expected, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

    reg [31:0] rdata;

    initial begin
        pclk       = 1'b0;
        presetn    = 1'b0;
        psel       = 1'b0;
        penable    = 1'b0;
        pwrite     = 1'b0;
        paddr      = 4'd0;
        pwdata     = 32'd0;
        gpio_in    = 8'd0;
        pass_count = 0;
        fail_count = 0;

        repeat (4) @(posedge pclk);
        presetn = 1'b1;
        repeat (4) @(posedge pclk);

        // Test 1: write DIR, read it back
        apb_write(4'h8, 32'h0000_00F0);
        apb_read(4'h8, rdata);
        check("DIR readback", rdata, 32'h0000_00F0);

        // Test 2: write DATA_OUT, check register readback and gpio_out pin
        apb_write(4'h0, 32'h0000_00A5);
        apb_read(4'h0, rdata);
        check("DATA_OUT readback", rdata, 32'h0000_00A5);
        #1;
        check("gpio_out pin value", {24'd0, gpio_out}, 32'h0000_00A5);

        // Test 3: drive gpio_in, check DATA_IN register reflects it
        gpio_in = 8'hC3;
        @(posedge pclk);
        apb_read(4'h4, rdata);
        check("DATA_IN reflects input pins", rdata, 32'h0000_00C3);

        // Test 4: INT_STATUS should have latched the gpio_in change (0x00 -> 0xC3)
        apb_read(4'hC, rdata);
        check("INT_STATUS latched input change", rdata, 32'h0000_00C3);

        // write-1-to-clear the interrupt bits we just saw
        apb_write(4'hC, 32'h0000_00C3);
        apb_read(4'hC, rdata);
        check("INT_STATUS cleared after write-1-to-clear", rdata, 32'h0000_0000);

        // Test 5: writing to the read-only DATA_IN register should assert PSLVERR
        apb_write(4'h4, 32'hFFFF_FFFF);
        #1;
        check("PSLVERR on illegal write to DATA_IN", {31'd0, pslverr}, 32'h0000_0001);

        $display("--------------------------------------------------");
        $display("APB GPIO test summary: %0d passed, %0d failed", pass_count, fail_count);
        $display("--------------------------------------------------");

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", fail_count);

        $finish;
    end

    initial begin
        #50000;
        $display("ERROR: testbench timeout -- simulation did not finish");
        $finish;
    end

endmodule
