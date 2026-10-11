// -----------------------------------------------------------------------------
// apb_gpio.v
// A small APB (AMBA Advanced Peripheral Bus) slave implementing a 4-register
// memory-mapped GPIO block:
//   0x0  DATA_OUT   (R/W) - output pin values
//   0x4  DATA_IN    (RO)  - input pin values (from gpio_in)
//   0x8  DIR        (R/W) - direction: 1 = output, 0 = input
//   0xC  INT_STATUS (R/W1C) - set when a watched input pin changes; write 1 to clear
// Follows the standard APB protocol: PSEL -> PENABLE (setup then access phase),
// with PREADY tied high (zero wait-state slave) and PSLVERR for bad addresses.
// -----------------------------------------------------------------------------
module apb_gpio #(
    parameter ADDR_WIDTH = 4
) (
    input  wire                    pclk,
    input  wire                    presetn,

    input  wire                    psel,
    input  wire                    penable,
    input  wire                    pwrite,
    input  wire [ADDR_WIDTH-1:0]   paddr,
    input  wire [31:0]             pwdata,
    output reg  [31:0]             prdata,
    output wire                    pready,
    output reg                     pslverr,

    input  wire [7:0]              gpio_in,
    output reg  [7:0]              gpio_out,
    output reg  [7:0]              gpio_dir
);

    localparam ADDR_DATA_OUT   = 4'h0,
               ADDR_DATA_IN    = 4'h4,
               ADDR_DIR        = 4'h8,
               ADDR_INT_STATUS = 4'hC;

    assign pready = 1'b1;   // zero wait-state slave

    reg [7:0] int_status;
    reg [7:0] gpio_in_prev;

    wire apb_write = psel && penable && pwrite;
    wire apb_read  = psel && penable && !pwrite;

    // Edge-detect on gpio_in to latch into INT_STATUS
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_in_prev <= 8'd0;
            int_status   <= 8'd0;
        end else begin
            gpio_in_prev <= gpio_in;
            int_status   <= int_status | (gpio_in ^ gpio_in_prev);
            if (apb_write && paddr == ADDR_INT_STATUS) begin
                int_status <= (int_status | (gpio_in ^ gpio_in_prev)) & ~pwdata[7:0]; // write-1-to-clear
            end
        end
    end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_out <= 8'd0;
            gpio_dir <= 8'd0;
            pslverr  <= 1'b0;
        end else begin
            pslverr <= 1'b0;
            if (apb_write) begin
                case (paddr)
                    ADDR_DATA_OUT: gpio_out <= pwdata[7:0];
                    ADDR_DIR:      gpio_dir <= pwdata[7:0];
                    ADDR_DATA_IN:  pslverr  <= 1'b1;   // read-only register written
                    ADDR_INT_STATUS: ; // handled above
                    default:       pslverr  <= 1'b1;   // unmapped address
                endcase
            end
        end
    end

    always @(*) begin
        prdata = 32'd0;
        if (apb_read) begin
            case (paddr)
                ADDR_DATA_OUT:   prdata = {24'd0, gpio_out};
                ADDR_DATA_IN:    prdata = {24'd0, gpio_in};
                ADDR_DIR:        prdata = {24'd0, gpio_dir};
                ADDR_INT_STATUS: prdata = {24'd0, int_status};
                default:         prdata = 32'd0;
            endcase
        end
    end

endmodule
