module fsm_control_unit (input  logic clk, rst,input  logic [7:0] sel,

output logic en_arith,
output logic en_logic,
output logic en_shift,
output logic en_muldiv,
output logic en_adv,
output logic write_en,

output logic [2:0] sel_decoded);

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
            write_en = 1;  // â­ VERY IMPORTANT
        end

    endcase
end

endmodule



module arithmetic_unit (input  logic clk, rst,input  logic en,input  logic [7:0] sel,input  logic [7:0] A, B,output logic [15:0] Y);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        Y <= 0;
    else if (en) begin            // ⭐ USE ENABLE
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

module logic_unit (input  logic clk, rst,input  logic en,input  logic [7:0] sel,input  logic [7:0] A, B,output logic [15:0] Y);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        Y <= 0;
    else if (en) begin
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

module shift_unit (input  logic clk, rst,input  logic en,input  logic [7:0] sel,input  logic [7:0] A,output logic [15:0] Y);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        Y <= 0;
    else if (en) begin
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

module muldiv_unit (input  logic clk, rst,input  logic en,input  logic [7:0] sel,input  logic [7:0] A, B,output logic [15:0] Y);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        Y <= 0;
    else if (en) begin
        case (sel[4:0])
            5'd0: Y <= A * B;
            5'd1: Y <= (B != 0) ? A / B : 0;
            default: Y <= 0;
        endcase
    end
end

endmodule

module advanced_unit (input  logic clk, rst,input  logic en,input  logic [7:0] sel,input  logic [7:0] A, B,output logic [15:0] Y);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        Y <= 0;
    else if (en) begin
        case (sel[4:0])
            5'd0: Y <= (A > B) ? A : B;
            5'd1: Y <= (A < B) ? A : B;
            5'd2: Y <= (A == B);  // 1 or 0
            default: Y <= 0;
        endcase
    end
end

endmodule

module output_mux (input  logic [2:0] sel_decoded,input  logic [15:0] Y_a, Y_l, Y_s, Y_m, Y_adv,output logic [15:0] Y);

always_comb begin
    case (sel_decoded)
        3'b000: Y = Y_a;
        3'b001: Y = Y_l;
        3'b010: Y = Y_s;
        3'b011: Y = Y_m;
        3'b100: Y = Y_adv;
        default: Y = 0;
    endcase
end

endmodule

module alu_top (input  logic clk, rst,input  logic [7:0] sel,input  logic [7:0] A, B,output logic [15:0] Y);

logic en_arith, en_logic, en_shift, en_muldiv, en_adv;
logic write_en;
logic [2:0] sel_decoded;

logic [15:0] Y_a, Y_l, Y_s, Y_m, Y_adv;
logic [15:0] Y_comb;

// GATED CLOCKS
logic clk_a, clk_l, clk_s, clk_m, clk_adv;

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
    .sel_decoded(sel_decoded)
);

// CLOCK GATING
assign clk_a   = clk & en_arith;
assign clk_l   = clk & en_logic;
assign clk_s   = clk & en_shift;
assign clk_m   = clk & en_muldiv;
assign clk_adv = clk & en_adv;

// FUNCTIONAL UNITS USING GATED CLOCKS

arithmetic_unit AU (
    .clk(clk_a),
    .rst(rst),
    .en(1'b1),
    .sel(sel),
    .A(A),
    .B(B),
    .Y(Y_a)
);

logic_unit LU (
    .clk(clk_l),
    .rst(rst),
    .en(1'b1),
    .sel(sel),
    .A(A),
    .B(B),
    .Y(Y_l)
);

shift_unit SU (
    .clk(clk_s),
    .rst(rst),
    .en(1'b1),
    .sel(sel),
    .A(A),
    .Y(Y_s)
);

muldiv_unit MU (
    .clk(clk_m),
    .rst(rst),
    .en(1'b1),
    .sel(sel),
    .A(A),
    .B(B),
    .Y(Y_m)
);

advanced_unit ADU (
    .clk(clk_adv),
    .rst(rst),
    .en(1'b1),
    .sel(sel),
    .A(A),
    .B(B),
    .Y(Y_adv)
);

// OUTPUT MUX
output_mux MUX (
    .sel_decoded(sel_decoded),
    .Y_a(Y_a),
    .Y_l(Y_l),
    .Y_s(Y_s),
    .Y_m(Y_m),
    .Y_adv(Y_adv),
    .Y(Y_comb)
);

// FINAL REGISTER
always_ff @(posedge clk or posedge rst) begin
    if (rst)
        Y <= 0;
    else if (write_en)
        Y <= Y_comb;
end

endmodule

module alu_tbeee;

logic clk, rst;
logic [7:0] sel;
logic [7:0] A, B;
logic [15:0] Y;

string state_name;

// ==================================================
// DUT
// ==================================================
alu_top DUT (
    .clk(clk),
    .rst(rst),
    .sel(sel),
    .A(A),
    .B(B),
    .Y(Y)
);

// ==================================================
// CLOCK GENERATION (10 ns period)
// ==================================================
always #5 clk = ~clk;

// ==================================================
// APPLY INPUT TASK
// ==================================================
task apply_input(input [7:0] sel_in, input [7:0] a_in, input [7:0] b_in);
begin
    // Wait until IDLE
    wait (DUT.CU.state == 0);

    // Apply inputs
    sel = sel_in;
    A   = a_in;
    B   = b_in;

    // FSM progression
    @(posedge clk); // DECODE
    @(posedge clk); // EXECUTE

    // Wait until WRITE
    wait (DUT.write_en == 1);

    // Return to IDLE
    @(posedge clk);
end
endtask

// ==================================================
// FULL DISPLAY BLOCK
// ==================================================

always @(posedge clk) begin

case (DUT.CU.state)
    0: state_name = "IDLE";
    1: state_name = "DECODE";
    2: state_name = "EXECUTE";
    3: state_name = "WRITE";
    default: state_name = "UNKNOWN";
endcase

$display("\n==============================================================");
$display("TIME = %0t | STATE = %s", $time, state_name);
$display("INPUTS : sel=%b | A=%0d | B=%0d", sel, A, B);

$display("EN : a=%b l=%b s=%b m=%b adv=%b",
    DUT.en_arith, DUT.en_logic, DUT.en_shift, DUT.en_muldiv, DUT.en_adv);

$display("Y_a   = %0d", DUT.Y_a);
$display("Y_l   = %0d", DUT.Y_l);
$display("Y_s   = %0d", DUT.Y_s);
$display("Y_m   = %0d", DUT.Y_m);
$display("Y_adv = %0d", DUT.Y_adv);

$display("MUX OUTPUT   = %0d", DUT.Y_comb);
$display("FINAL OUTPUT = %0d", Y);
$display("WRITE_EN = %b", DUT.write_en);

$display("==============================================================");

end

always @(posedge DUT.clk_a)$display(">>> clk_a ACTIVE at time %0t", $time);

always @(posedge DUT.clk_l)$display(">>> clk_l ACTIVE at time %0t", $time);

always @(posedge DUT.clk_s)$display(">>> clk_s ACTIVE at time %0t", $time);

always @(posedge DUT.clk_m)$display(">>> clk_m ACTIVE at time %0t", $time);

always @(posedge DUT.clk_adv)$display(">>> clk_adv ACTIVE at time %0t", $time);

// ==================================================
// TEST CASES
// ==================================================
initial begin
    clk = 0;
    rst = 1;
    sel = 0;
    A   = 0;
    B   = 0;

    // RESET
    #15 rst = 0;

    // =========================
    // TESTS
    // =========================

    // ADD
    apply_input(8'b00000000, 10, 5);

    // SUB
    apply_input(8'b00000001, 15, 3);

    // AND
    apply_input(8'b00100000, 12, 6);

    // XOR
    apply_input(8'b00100010, 9, 5);

    // SHIFT RIGHT
    apply_input(8'b01000001, 8'b11110000, 0);

    // ROTATE LEFT
    apply_input(8'b01000010, 8'b10101010, 0);

    // MULTIPLY
    apply_input(8'b01100000, 7, 3);

    // DIVIDE
    apply_input(8'b01100001, 20, 4);

    // MAX
    apply_input(8'b10000000, 25, 15);

    // MIN
    apply_input(8'b10000001, 25, 15);

    // EQUAL
    apply_input(8'b10000010, 10, 10);

    // FINISH
    #50;
    $stop;
end

endmodule