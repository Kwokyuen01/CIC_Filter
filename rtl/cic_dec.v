/*****************************************************************************
*   模块名称 : cic_dec
*   模块描述 : CIC抽取器模块，必须使用有符号整数
******************************************************************************/
module cic_dec
#(
    parameter R     = 100,              // 抽取倍率（Decimation factor）
    parameter M     = 2 ,               // 差分延迟，必须是1或2
    parameter N     = 3 ,               // 阶数，CIC滤波器的积分器和微分器的阶数相同
    parameter BIN   = 10,               // 输入数据位宽
    parameter COUT  = 16,               // 输出裁剪后的数据位宽
    parameter CUT_METHOD = "ROUND",     // 裁剪方式，ROUND为四舍五入，CUT为截断低位
    parameter BOUT  = 33,               // 输出数据宽度，用于防止溢出，手动计算为 (BIN + $clog2((R*M)**N))
    parameter fs    = 20_000_000        // 输入采样率
)
(
    input   wire            clk     ,   // 时钟信号，频率等于din的采样速率
    input   wire            rst_n   ,   // 复位信号，低电平有效
    input   wire            enable_cic  ,   // CIC使能信号，高电平有效
    input   wire [BIN-1 :0] din     ,   // 输入数据
    output  wire [BOUT-1:0] dout    ,   // 原始输出数据
    output  wire [COUT-1:0] dout_cut,   // 裁剪后的输出数据
    output  wire            dval        // 输出数据有效信号
);

// 计算输入和输出的奈奎斯特频率
localparam fInput_nyquist  = fs / 2;
localparam fOutput_nyquist = fInput_nyquist / R;

// 在仿真时显示参数信息
initial begin
    $display("\n------------CIC_DEC------------\nR   : %0d", R);
    $display("M   : %0d", M);
    $display("N   : %0d", N);
    $display("BIN : %0d bits", BIN);
    $display("BOUT: %0d bits", BOUT);
    $display("COUT: %0d bits", COUT);
    $display("cut method         : %s", CUT_METHOD);
    $display("input nyquist freq : %0d Hz", fInput_nyquist);
    $display("output nyquist freq: %0d Hz", fOutput_nyquist);
    $display("cnt0 width         : %0d bits\n", $clog2(R));
end

// 根据裁剪方式选择裁剪逻辑
generate
    if (CUT_METHOD == "ROUND") begin
        // 四舍五入裁剪
        wire carry_bit = dout[BOUT-1] ? (dout[BOUT-(COUT-1)-1-1] & (|dout[BOUT-(COUT-1)-1-1-1:0])) : dout[BOUT-(COUT-1)-1-1];
        assign dout_cut = {dout[BOUT-1], dout[BOUT-1:BOUT-(COUT-1)-1]} + carry_bit;
    end else if (CUT_METHOD == "CUT") begin
        // 截断裁剪
        assign dout_cut = (dout >> (BOUT - COUT));
    end
endgenerate

/*
*   积分器模块
*   将输入信号进行N阶积分
*/
generate
    genvar i;
    for (i = 0; i < N; i = i + 1) begin : LOOP
        reg  [BOUT-1:0] inte;             // 每级积分器的寄存器
        wire [BOUT-1:0] sum;              // 每级积分器的输出和

        if (i == 0) begin
            // 第一阶积分器，输入为原始数据din
            assign sum = inte + {{(BOUT-BIN){din[BIN-1]}}, din};
        end else begin
            // 后续阶的积分器，输入为前一级积分器的输出
            assign sum = inte + (LOOP[i-1].sum);
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)
                inte <= {(BOUT){1'd0}};   // 复位时清零
            else if (enable_cic)  // 添加enable控制
                inte <= sum;
        end    
    end
endgenerate

// 获取最后一级积分器的输出
wire [BOUT-1:0] inte_out;
assign inte_out = LOOP[N-1].sum;

/*
*   抽取逻辑
*   根据抽取倍率R控制输出速率
*/
reg [$clog2(R)-1:0] cnt0;            // 抽取计数器
reg [BOUT-1:0] dec_out;               // 抽取后的输出数据
assign dval = enable_cic && (cnt0 == (R-1));        // 当计数器达到R-1时，dval信号为高，表示数据有效

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt0    <= 'd0;               // 复位计数器
        dec_out <= 'd0;               // 复位抽取后的输出数据
    end else if (enable_cic) begin  // 添加enable控制
        cnt0    <= dval ? 'd0 : cnt0 + 1'd1;
        dec_out <= dval ? inte_out : dec_out;
    end
end

/*
*   微分器模块
*   将抽取后的信号进行N阶差分处理
*/
generate
    genvar j;
    for (j = 0; j < N; j = j + 1) begin : LOOP2
        reg  [BOUT-1:0] comb;               // 每级微分器寄存器
        wire [BOUT-1:0] sub;                // 每级微分器的差分结果

        if (j == 0) begin
            if (M == 1) begin
                // 差分延迟为1的情况
                assign sub = dec_out - comb;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        comb <= {(BOUT){1'd0}};   // 复位微分器寄存器
                    else if (enable_cic && dval)  // 添加enable控制
                        comb <= dec_out;
                end  
            end else begin
                // 差分延迟为2的情况
                reg [BOUT-1:0] comb1;
                assign sub = dec_out - comb1;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        comb <= {(BOUT){1'd0}};
                        comb1 <= {(BOUT){1'd0}};
                    end else if (enable_cic && dval) begin  // 添加enable控制
                        comb <= dec_out;
                        comb1 <= comb;
                    end
                end  
            end
        end else begin
            // 后续级的微分器
            if (M == 1) begin
                assign sub = LOOP2[j-1].sub - comb;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        comb <= {(BOUT){1'd0}};
                    else if (enable_cic && dval)  // 添加enable控制
                        comb <= LOOP2[j-1].sub;
                end  
            end else begin
                reg [BOUT-1:0] comb1;
                assign sub = LOOP2[j-1].sub - comb1;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        comb <= {(BOUT){1'd0}};
                        comb1 <= {(BOUT){1'd0}};
                    end else if (enable_cic && dval) begin  // 添加enable控制
                        comb <= LOOP2[j-1].sub;
                        comb1 <= comb;
                    end
                end  
            end
        end
    end
endgenerate

// 最后一级微分器的输出作为模块的最终输出
assign dout = LOOP2[N-1].sub;

endmodule
