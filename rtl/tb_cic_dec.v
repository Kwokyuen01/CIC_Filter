//~ `New testbench
`timescale  1ns / 1ps  // 仿真时间单位/时间精度

module tb_cic_dec;
// -------- 参数定义 --------
parameter PERIOD = 10;           // 时钟周期为500ns，对应时钟频率1MHz
                                
parameter R      = 64;           // CIC滤波器的抽取倍率
parameter M      = 1;            // CIC滤波器的差分延迟，只能取1或2
parameter N      = 4;            // CIC滤波器的阶数，积分器和梳状器各4级
parameter BIN    = 16;           // 输入数据位宽16位
parameter COUT   = 16;           // 输出截位后的数据位宽16位
// BOUT计算CIC滤波器内部最大位宽，防止数据溢出
// BOUT = 输入位宽 + log2(抽取倍率×差分延迟)^阶数 向上取整
parameter BOUT   = (BIN + $clog2((R*M)**N));
parameter fs     = 1_000_000;    // 采样率1MHz

// -------- 信号定义 --------
reg  clk = 0;                    // 时钟信号，初始值为0
reg  rst_n = 0;                  // 复位信号，低电平有效，初始值为0
wire dval;                       // 输出数据有效标志
integer fp;                      // 文件指针，用于保存输出数据
reg [63:0] cnt0 = 0, cnt1 = 0;   // 64位计数器，cnt0计数输出数据，cnt1计数输入数据
reg signed [BIN-1:0] din;        // 有符号输入数据
wire signed [BOUT-1:0] dout;     // 有符号输出数据(未截位)
wire signed [COUT-1:0] dout_cut; // 有符号输出数据(截位后)
reg [BIN-1:0] sine[0:1024*256-1]; // 存储输入正弦波数据的数组
reg enable_cic = 1'b0;
// -------- 时钟生成 --------
initial begin
    forever #(PERIOD/2) clk = ~clk;  // 产生周期为PERIOD的时钟信号
end

// -------- 复位信号生成 --------
initial begin
    #(PERIOD*2) rst_n = 1;          // 延迟2个时钟周期后释放复位
end

// -------- 主要处理逻辑 --------
always @ (posedge clk) begin
    // 在时钟上升沿时从sine数组读取输入数据
    enable_cic <= 1'b1;
    din  <= sine[cnt1];  
    // cnt1循环计数，达到最大值时归零
    cnt1 <= (cnt1 == 1024*256) ? 0 : cnt1 + 1;

    // 当输出数据有效时，将数据写入文件
    if (dval) begin
        $fwrite(fp, "%d\n", dout_cut);
        cnt0 <= cnt0 + 1;
    end

    // 当处理完所有数据后，关闭文件并结束仿真
    if (cnt1 == 1024*256) begin
        enable_cic <= 1'b0;
        $fclose(fp);
        $finish;
    end
end

// -------- 实例化CIC抽取滤波器 --------
cic_dec #(
    .R         (R       ),    // 设置抽取倍率
    .M         (M       ),    // 设置差分延迟
    .N         (N       ),    // 设置滤波器阶数
    .BIN       (BIN     ),    // 设置输入位宽
    .COUT      (COUT    ),    // 设置输出位宽
    .BOUT      (BOUT    ),    // 设置内部位宽
    .CUT_METHOD("ROUND" ),    // 设置截位方法为四舍五入
    .fs        (fs      )     // 设置采样率
) u_cic_dec (
    .clk     ( clk      ),    // 时钟输入
    .rst_n   ( rst_n    ),    // 复位输入
    .enable_cic(enable_cic),  // 新增enable_cic信号
    .din     ( din      ),    // 数据输入
    .dout    ( dout     ),    // 未截位数据输出
    .dout_cut( dout_cut ),    // 截位后数据输出
    .dval    ( dval     )     // 输出数据有效标志
);

// -------- 初始化任务 --------
initial begin
    $dumpfile("wave.vcd");         // 创建波形文件
    $dumpvars(0, u_cic_dec);       // 转储所有信号
    // 打开输出文件
    fp = $fopen("E:/Matlab_Project/dout.txt", "w");
    // 从文件读取输入信号数据
    $readmemh("E:/ALINX_Project/CIC_Demo_v2/700Hz_1024x256_transpose.txt", sine);
    //enable_cic <= 1'b1;
end

endmodule
