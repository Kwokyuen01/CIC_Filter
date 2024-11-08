//~ `New testbench
`timescale  1ns / 1ps  // ����ʱ�䵥λ/ʱ�侫��

module tb_cic_dec;
// -------- �������� --------
parameter PERIOD = 10;           // ʱ������Ϊ500ns����Ӧʱ��Ƶ��1MHz
                                
parameter R      = 64;           // CIC�˲����ĳ�ȡ����
parameter M      = 1;            // CIC�˲����Ĳ���ӳ٣�ֻ��ȡ1��2
parameter N      = 4;            // CIC�˲����Ľ���������������״����4��
parameter BIN    = 16;           // ��������λ��16λ
parameter COUT   = 16;           // �����λ�������λ��16λ
// BOUT����CIC�˲����ڲ����λ����ֹ�������
// BOUT = ����λ�� + log2(��ȡ���ʡ�����ӳ�)^���� ����ȡ��
parameter BOUT   = (BIN + $clog2((R*M)**N));
parameter fs     = 1_000_000;    // ������1MHz

// -------- �źŶ��� --------
reg  clk = 0;                    // ʱ���źţ���ʼֵΪ0
reg  rst_n = 0;                  // ��λ�źţ��͵�ƽ��Ч����ʼֵΪ0
wire dval;                       // ���������Ч��־
integer fp;                      // �ļ�ָ�룬���ڱ����������
reg [63:0] cnt0 = 0, cnt1 = 0;   // 64λ��������cnt0����������ݣ�cnt1������������
reg signed [BIN-1:0] din;        // �з�����������
wire signed [BOUT-1:0] dout;     // �з����������(δ��λ)
wire signed [COUT-1:0] dout_cut; // �з����������(��λ��)
reg [BIN-1:0] sine[0:1024*256-1]; // �洢�������Ҳ����ݵ�����
reg enable_cic = 1'b0;
// -------- ʱ������ --------
initial begin
    forever #(PERIOD/2) clk = ~clk;  // ��������ΪPERIOD��ʱ���ź�
end

// -------- ��λ�ź����� --------
initial begin
    #(PERIOD*2) rst_n = 1;          // �ӳ�2��ʱ�����ں��ͷŸ�λ
end

// -------- ��Ҫ�����߼� --------
always @ (posedge clk) begin
    // ��ʱ��������ʱ��sine�����ȡ��������
    enable_cic <= 1'b1;
    din  <= sine[cnt1];  
    // cnt1ѭ���������ﵽ���ֵʱ����
    cnt1 <= (cnt1 == 1024*256) ? 0 : cnt1 + 1;

    // �����������Чʱ��������д���ļ�
    if (dval) begin
        $fwrite(fp, "%d\n", dout_cut);
        cnt0 <= cnt0 + 1;
    end

    // ���������������ݺ󣬹ر��ļ�����������
    if (cnt1 == 1024*256) begin
        enable_cic <= 1'b0;
        $fclose(fp);
        $finish;
    end
end

// -------- ʵ����CIC��ȡ�˲��� --------
cic_dec #(
    .R         (R       ),    // ���ó�ȡ����
    .M         (M       ),    // ���ò���ӳ�
    .N         (N       ),    // �����˲�������
    .BIN       (BIN     ),    // ��������λ��
    .COUT      (COUT    ),    // �������λ��
    .BOUT      (BOUT    ),    // �����ڲ�λ��
    .CUT_METHOD("ROUND" ),    // ���ý�λ����Ϊ��������
    .fs        (fs      )     // ���ò�����
) u_cic_dec (
    .clk     ( clk      ),    // ʱ������
    .rst_n   ( rst_n    ),    // ��λ����
    .enable_cic(enable_cic),  // ����enable_cic�ź�
    .din     ( din      ),    // ��������
    .dout    ( dout     ),    // δ��λ�������
    .dout_cut( dout_cut ),    // ��λ���������
    .dval    ( dval     )     // ���������Ч��־
);

// -------- ��ʼ������ --------
initial begin
    $dumpfile("wave.vcd");         // ���������ļ�
    $dumpvars(0, u_cic_dec);       // ת�������ź�
    // ������ļ�
    fp = $fopen("E:/Matlab_Project/dout.txt", "w");
    // ���ļ���ȡ�����ź�����
    $readmemh("E:/ALINX_Project/CIC_Demo_v2/700Hz_1024x256_transpose.txt", sine);
    //enable_cic <= 1'b1;
end

endmodule