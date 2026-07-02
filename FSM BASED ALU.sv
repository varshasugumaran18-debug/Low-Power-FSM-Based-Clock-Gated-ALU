module fsm_control_unit (
    input  logic clk, rst,
    input  logic [7:0] sel,

    output logic en_arith,
    output logic en_logic,
    output logic en_shift,
    output logic en_muldiv,
    output logic en_adv,
    output logic write_en,
output logic [2:0] sel_decoded,
output logic [2:0] state_out   // ? ADD THIS
);
    typedef enum logic [2:0] {
        IDLE, DECODE, EXECUTE, WRITE
    } state_t;

    state_t state, next_state;

   
    // STATE REGISTER
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // NEXT STATE
    always_comb begin
        case (state)
            IDLE:    next_state = DECODE;
            DECODE:  next_state = EXECUTE;
            EXECUTE: next_state = WRITE;
            WRITE:   next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // DECODE STAGE
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            sel_decoded <= 0;
        else if (state == DECODE)
            sel_decoded <= sel[7:5];
    end

    // OUTPUT LOGIC
    always_comb begin
        en_arith  = 0;
        en_logic  = 0;
        en_shift  = 0;
        en_muldiv = 0;
        en_adv    = 0;
        write_en  = 0;

        case (state)

            IDLE: begin
                // do nothing
            end

            DECODE: begin
                // only decoding, no enable
            end
EXECUTE: begin
                case (sel_decoded)
                    3'b000: en_arith  = 1;
                    3'b001: en_logic  = 1;
                    3'b010: en_shift  = 1;
                    3'b011: en_muldiv = 1;
                    3'b100: en_adv    = 1;
                    default: en_arith = 1;
                endcase
            end

            WRITE: begin
                write_en = 1;  // тн VERY IMPORTANT
            end

        endcase
    end
assign state_out = state;
endmodule



module arithmetic_unit (
    input  logic clk, rst,
    input  logic [7:0] sel,
    input  logic [7:0] A, B,
    output logic [15:0] Y
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Y <= 0;
        else  begin            
            case (sel[4:0])
                5'd0: Y <= A + B;
                5'd1: Y <= A - B;
                5'd2: Y <= A + 1;
                5'd3: Y <= A - 1;
                5'd4: Y <= A + B + 1;
                5'd5: Y <= A - B - 1;
                default: Y <= 0;
            endcase
        end
    end
endmodule

module logic_unit (
    input  logic clk, rst,
    input  logic [7:0] sel,
    input  logic [7:0] A, B,
    output logic [15:0] Y
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Y <= 0;
        else  begin
            case (sel[4:0])
                5'd0: Y <= A & B;
                5'd1: Y <= A | B;
                5'd2: Y <= A ^ B;
                5'd3: Y <= ~A;
                5'd4: Y <= ~(A & B);
                5'd5: Y <= ~(A | B);
                5'd6: Y <= ~(A ^ B);
                default: Y <= A;
            endcase
        end
    end
endmodule


module shift_unit (
    input  logic clk, rst,
    input  logic [7:0] sel,
    input  logic [7:0] A,
    output logic [15:0] Y
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Y <= 0;
        else  begin
            case (sel[4:0])
                5'd0: Y <= A << 1;
                5'd1: Y <= A >> 1;
                5'd2: Y <= {A[6:0], A[7]};   // rotate left
                5'd3: Y <= {A[0], A[7:1]};   // rotate right
                default: Y <= A;
            endcase
        end
    end
endmodule


module muldiv_unit (
    input  logic clk, rst,
    input  logic [7:0] sel,
    input  logic [7:0] A, B,
    output logic [15:0] Y
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Y <= 0;
        else  begin
            case (sel[4:0])
                5'd0: Y <= A * B;
                5'd1: Y <= (B != 0) ? A / B : 0;
                default: Y <= 0;
            endcase
        end
    end
endmodule


module advanced_unit (
    input  logic clk, rst,
    input  logic [7:0] sel,
    input  logic [7:0] A, B,
    output logic [15:0] Y
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Y <= 0;
        else  begin
            case (sel[4:0])
                5'd0: Y <= (A > B) ? A : B;
                5'd1: Y <= (A < B) ? A : B;
                5'd2: Y <= (A == B);  // 1 or 0
                default: Y <= 0;
            endcase
        end
    end
endmodule


module output_mux (
    input  logic en_arith, en_logic, en_shift, en_muldiv, en_adv,
    input  logic [15:0] Y_a, Y_l, Y_s, Y_m, Y_adv,
    output logic [15:0] Y
);

    always_comb begin
        if (en_arith)      Y = Y_a;
        else if (en_logic) Y = Y_l;
        else if (en_shift) Y = Y_s;
        else if (en_muldiv)Y = Y_m;
        else if (en_adv)   Y = Y_adv;
        else               Y = 0;
    end

endmodule

module alu_top (
    input  logic clk, rst,
    input  logic [7:0] sel,
    input  logic [7:0] A, B,
    output logic [15:0] Y,
    output logic [15:0] Y_a_out, Y_l_out, Y_s_out, Y_m_out, Y_adv_out,
output logic [2:0] state_out,
output logic [4:0] en_out,
output logic clk_a, clk_l, clk_s, clk_m, clk_adv
);

    logic en_arith, en_logic, en_shift, en_muldiv, en_adv;
    logic write_en;
    logic [2:0] sel_decoded;

    logic [15:0] Y_a, Y_l, Y_s, Y_m, Y_adv;
    logic [15:0] Y_comb;
logic [15:0] Y_reg;   // ? ADD HERE
assign Y_a_out   = Y_a;
assign Y_l_out   = Y_l;
assign Y_s_out   = Y_s;
assign Y_m_out   = Y_m;
assign Y_adv_out = Y_adv;
logic slow_clk;
assign clk_a   = clk;
assign clk_l   = clk;
assign clk_s   = clk;
assign clk_m   = clk;
assign clk_adv = clk;


    // FSM CONTROL
   fsm_control_unit CU (
    .clk(clk),
    .rst(rst),
    .sel(sel),
    .en_arith(en_arith),
    .en_logic(en_logic),
    .en_shift(en_shift),
    .en_muldiv(en_muldiv),
    .en_adv(en_adv),
    .write_en(write_en),
    .sel_decoded(sel_decoded),
    .state_out(state_out)   // ? ADD THIS
);


assign en_out = {
    en_adv,
    en_muldiv,
    en_shift,
    en_logic,
    en_arith
};
    // ==================================================
    // FUNCTIONAL UNITS (NO CLOCK GATING)
    // ==================================================

    arithmetic_unit AU (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .A(A),
        .B(B), 
        .Y(Y_a)
    );

    logic_unit LU (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .A(A),
        .B(B),
        .Y(Y_l)
    );

    shift_unit SU (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .A(A),
        .Y(Y_s)
    );

    muldiv_unit MU (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .A(A),
        .B(B),
        .Y(Y_m)
    );

    advanced_unit ADU (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .A(A),
        .B(B),
        .Y(Y_adv)
    );

    // ==================================================
    // MUX
    // ==================================================
   output_mux MUX (
       .en_arith(en_arith),
       .en_logic(en_logic),
       .en_shift(en_shift),
       .en_muldiv(en_muldiv),
       .en_adv(en_adv),

       .Y_a(Y_a),
       .Y_l(Y_l),
       .Y_s(Y_s),
       .Y_m(Y_m),
       .Y_adv(Y_adv),
       .Y(Y_comb)
   );


    // ==================================================
    // FINAL REGISTER (FSM WRITE CONTROL)
    // ==================================================
    always_ff @(posedge clk or posedge rst) begin
       if (rst)
           Y_reg <= 0;
       else if (state_out == 2)   // EXECUTE state
           Y_reg <= Y_comb;
    end
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Y <= 0;
        else if (write_en)
            Y <= Y_reg;
    end

endmodule





module alu_tbhhh;

    logic clk, rst;
    logic [7:0] sel;
    logic [7:0] A, B;
    logic [15:0] Y;

    logic [2:0] state_out;
    logic [4:0] en_out;
    logic clk_a, clk_l, clk_s, clk_m, clk_adv;
    logic [15:0] Y_a, Y_l, Y_s, Y_m, Y_adv;


    string state_name;

    // DUT
    alu_top DUT (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .A(A),
        .B(B),
        .Y(Y),
        .state_out(state_out),
        .en_out(en_out),
        .clk_a(clk_a),
        .clk_l(clk_l),
        .clk_s(clk_s),
        .clk_m(clk_m),
        .clk_adv(clk_adv),
        .Y_a_out(Y_a),
        .Y_l_out(Y_l),
        .Y_s_out(Y_s),
        .Y_m_out(Y_m),
        .Y_adv_out(Y_adv)
      

    );

    // CLOCK
    always #5 clk = ~clk;

    // DISPLAY
   always @(posedge clk) begin
    #1;   // ? ADD HERE
        case (state_out)
            0: state_name = "IDLE";
            1: state_name = "DECODE";
            2: state_name = "EXECUTE";
            3: state_name = "WRITE";
            default: state_name = "UNKNOWN";
        endcase

        $display("\n=================================================");
        $display("TIME=%0t | STATE=%s", $time, state_name);

        $display("INPUTS : sel=%b | A=%0d | B=%0d", sel, A, B);

        $display("ENABLES : %b", en_out);

        // CLOCKS (IMPORTANT FOR YOUR COMPARISON)
        $display("CLOCKS : clk=%b | clk_a=%b | clk_l=%b | clk_s=%b | clk_m=%b | clk_adv=%b",
            clk, clk_a, clk_l, clk_s, clk_m, clk_adv);
        $display("outputs : y_a=%b | y_l=%b | y_s=%b | y_m=%b | y_adv=%b",
             Y_a, Y_l, Y_s, Y_m, Y_adv);

        $display("OUTPUT Y = %0d", Y);

        $display("=================================================");

    end

    // TESTS
initial begin
    clk = 0;
    rst = 1;
    sel = 0;
    A   = 0;
    B   = 5;

    #15 rst = 0;

    // ==============================
    // ARITHMETIC BLOCK (ADD)
    // sel[7:5] = 000 ? arithmetic
    // sel[4:0] = 00000 ? A + B
    // ==============================
    sel = 8'b00000000; A = 10; B = 5; #40;

    // ==============================
    // LOGIC BLOCK (AND)
    // sel[7:5] = 001 ? logic
    // sel[4:0] = 00000 ? A & B
    // ==============================
    sel = 8'b00100000; A = 12; B = 5; #40;

    // ==============================
    // SHIFT BLOCK (LEFT SHIFT)
    // sel[7:5] = 010 ? shift
    // sel[4:0] = 00000 ? A << 1
    // ==============================
    sel = 8'b01000000; A = 8; #40;

    // ==============================
    // MULDIV BLOCK (MULTIPLY)
    // sel[7:5] = 011 ? mul/div
    // sel[4:0] = 00000 ? A * B
    // ==============================
    sel = 8'b01100000; A = 6; B = 3; #40;

    // ==============================
    // ADVANCED BLOCK (MAX)
    // sel[7:5] = 100 ? advanced
    // sel[4:0] = 00000 ? max(A,B)
    // ==============================
    sel = 8'b10000000; A = 25; B = 15; #40;

    #50 $stop;
end

endmodule
