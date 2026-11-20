// SPDX-License-Identifier: Apache-2.0
// ROBOCORE-8: eight dedicated inputs, eight dedicated outputs.
// Physical motor drivers and sensor conditioning are external.
`default_nettype none
module tt_um_robocore8 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // ui[0] front obstacle; ui[1] left obstacle; ui[2] right obstacle
    // ui[3] autonomous mode (1=auto, 0=manual)
    // ui[5:4] manual command: 00=stop, 01=forward, 10=left, 11=right
    // ui[6] arm/enable; ui[7] heartbeat toggle from controller
    // uo[0] left forward; uo[1] right forward
    // uo[2] left reverse; uo[3] right reverse
    // uo[4] brake/stop; uo[5] front obstacle
    // uo[6] watchdog link alive; uo[7] autonomous mode echo
    // Heartbeat MUST toggle at least once every 1024 clock cycles.
    // The timeout is expressed in clock cycles, not milliseconds.
    reg heartbeat_last;
    reg heartbeat_seen;
    reg [9:0] watchdog_count;
    wire heartbeat_edge = ui_in[7] ^ heartbeat_last;
    wire link_ok = heartbeat_seen && (watchdog_count != 10'd1023);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            heartbeat_last <= 1'b0;
            heartbeat_seen <= 1'b0;
            watchdog_count <= 10'd0;
        end else if (!ena || !ui_in[6]) begin
            // A new heartbeat transition is required after disarming.
            heartbeat_last <= ui_in[7];
            heartbeat_seen <= 1'b0;
            watchdog_count <= 10'd0;
        end else begin
            heartbeat_last <= ui_in[7];
            if (heartbeat_edge) begin
                heartbeat_seen <= 1'b1;
                watchdog_count <= 10'd0;
            end else if (watchdog_count != 10'd1023) begin
                watchdog_count <= watchdog_count + 10'd1;
            end
        end
    end

    reg left_fwd;
    reg right_fwd;
    reg left_rev;
    reg right_rev;
    wire enabled = rst_n && ena && ui_in[6] && link_ok;
    always @* begin
        left_fwd = 1'b0;
        right_fwd = 1'b0;
        left_rev = 1'b0;
        right_rev = 1'b0;
        if (enabled) begin
            if (ui_in[3]) begin
                // Autonomous, deterministic and conservative priority.
                if (!ui_in[0]) begin
                    left_fwd = 1'b1;
                    right_fwd = 1'b1;
                end else if (!ui_in[1]) begin
                    // Pivot left when front blocked and left sector clear.
                    left_rev = 1'b1;
                    right_fwd = 1'b1;
                end else if (!ui_in[2]) begin
                    // Pivot right when front/left blocked and right clear.
                    left_fwd = 1'b1;
                    right_rev = 1'b1;
                end
                // All blocked: brake. No automatic backward translation.
            end else begin
                case (ui_in[5:4])
                    2'b01: if (!ui_in[0]) begin
                        left_fwd = 1'b1;
                        right_fwd = 1'b1;
                    end
                    2'b10: if (!ui_in[1]) begin
                        left_rev = 1'b1;
                        right_fwd = 1'b1;
                    end
                    2'b11: if (!ui_in[2]) begin
                        left_fwd = 1'b1;
                        right_rev = 1'b1;
                    end
                    default: begin end
                endcase
            end
        end
    end
    wire stopped = !(left_fwd | right_fwd | left_rev | right_rev);
    assign uo_out = {ui_in[3], link_ok, ui_in[0], stopped,
                     right_rev, left_rev, right_fwd, left_fwd};
    // All bidirectional pins unused, always high-impedance from the chip.
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused = &{uio_in, 1'b0};
endmodule
`default_nettype wire
