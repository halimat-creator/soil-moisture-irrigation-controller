module tt_um_moisture_irrigation (
    input  wire [7:0] ui_in,    // ui_in[0]=comp0, ui_in[1]=comp1
    output wire [7:0] uo_out,   // uo_out[0]=pump, uo_out[1]=invalid_flag
    input  wire [7:0] uio_in,   // not used
    output wire [7:0] uio_out,  // not used
    output wire [7:0] uio_oe,   // set to 0 (all bidirectional as input)
    input  wire       ena,      // not used
    input  wire       clk,      // clock
    input  wire       rst_n     // active-low reset (TinyTapeout standard)
);

    // Map inputs
    wire comp0 = ui_in[0];
    wire comp1 = ui_in[1];
    wire rst   = ~rst_n;        // Convert active-low to active-high

    // Internal signals
    wire pump;
    wire invalid_flag;

    // Map outputs
    assign uo_out[0] = pump;
    assign uo_out[1] = invalid_flag;
    assign uo_out[7:2] = 6'b0;  // unused outputs set to 0
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // ─── Comparator Encoding ───────────────────────────────────────────
    // {comp1, comp0} = 2'b00 → DRY   → IRRIGATE
    // {comp1, comp0} = 2'b01 → MILD  → IDLE
    // {comp1, comp0} = 2'b11 → WET   → SATURATED
    // {comp1, comp0} = 2'b10 → INVALID
    // ──────────────────────────────────────────────────────────────────

    wire [1:0] moisture_content;
    assign moisture_content = {comp1, comp0};

    // State encoding
    localparam [1:0] IDLE      = 2'b00,
                     IRRIGATE  = 2'b01,
                     SATURATED = 2'b10,
                     INVALID   = 2'b11;

    reg [1:0] current_state, next_state;

    // ─── State Memory (Synchronous Reset) ─────────────────────────────
    always @(posedge clk) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // ─── Next State Logic ──────────────────────────────────────────────
    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                case (moisture_content)
                    2'b10:   next_state = INVALID;
                    2'b00:   next_state = IRRIGATE;
                    2'b01:   next_state = IDLE;
                    2'b11:   next_state = SATURATED;
                    default: next_state = INVALID;
                endcase
            end

            IRRIGATE: begin
                case (moisture_content)
                    2'b10:   next_state = INVALID;
                    2'b00:   next_state = IRRIGATE;
                    2'b01:   next_state = IDLE;
                    2'b11:   next_state = SATURATED;
                    default: next_state = INVALID;
                endcase
            end

            SATURATED: begin
                case (moisture_content)
                    2'b10:   next_state = INVALID;
                    2'b11:   next_state = SATURATED;
                    2'b01:   next_state = IDLE;
                    2'b00:   next_state = IRRIGATE;
                    default: next_state = INVALID;
                endcase
            end

            INVALID: begin
                if (moisture_content != 2'b10)
                    next_state = IDLE;
                else
                    next_state = INVALID;
            end

            default: next_state = IDLE;
        endcase
    end

    // ─── Output Logic (Moore) ─────────────────────────────────────────
    reg pump_reg, invalid_flag_reg;

    always @(*) begin
        pump_reg         = 1'b0;
        invalid_flag_reg = 1'b0;

        case (current_state)
            IDLE:      begin pump_reg = 1'b0; invalid_flag_reg = 1'b0; end
            IRRIGATE:  begin pump_reg = 1'b1; invalid_flag_reg = 1'b0; end
            SATURATED: begin pump_reg = 1'b0; invalid_flag_reg = 1'b0; end
            INVALID:   begin pump_reg = 1'b0; invalid_flag_reg = 1'b1; end
            default:   begin pump_reg = 1'b0; invalid_flag_reg = 1'b0; end
        endcase
    end

    assign pump         = pump_reg;
    assign invalid_flag = invalid_flag_reg;

endmodule
