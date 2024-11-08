/*****************************************************************************
*   ģ������ : cic_dec
*   ģ������ : CIC��ȡ��ģ�飬����ʹ���з�������
******************************************************************************/
module cic_dec
#(
    parameter R     = 100,              // ��ȡ���ʣ�Decimation factor��
    parameter M     = 2 ,               // ����ӳ٣�������1��2
    parameter N     = 3 ,               // ������CIC�˲����Ļ�������΢�����Ľ�����ͬ
    parameter BIN   = 10,               // ��������λ��
    parameter COUT  = 16,               // ����ü��������λ��
    parameter CUT_METHOD = "ROUND",     // �ü���ʽ��ROUNDΪ�������룬CUTΪ�ضϵ�λ
    parameter BOUT  = 33,               // ������ݿ�ȣ����ڷ�ֹ������ֶ�����Ϊ (BIN + $clog2((R*M)**N))
    parameter fs    = 20_000_000        // ���������
)
(
    input   wire            clk     ,   // ʱ���źţ�Ƶ�ʵ���din�Ĳ�������
    input   wire            rst_n   ,   // ��λ�źţ��͵�ƽ��Ч
    input   wire            enable_cic  ,   // CICʹ���źţ��ߵ�ƽ��Ч
    input   wire [BIN-1 :0] din     ,   // ��������
    output  wire [BOUT-1:0] dout    ,   // ԭʼ�������
    output  wire [COUT-1:0] dout_cut,   // �ü�����������
    output  wire            dval        // ���������Ч�ź�
);

// ���������������ο�˹��Ƶ��
localparam fInput_nyquist  = fs / 2;
localparam fOutput_nyquist = fInput_nyquist / R;

// �ڷ���ʱ��ʾ������Ϣ
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

// ���ݲü���ʽѡ��ü��߼�
generate
    if (CUT_METHOD == "ROUND") begin
        // ��������ü�
        wire carry_bit = dout[BOUT-1] ? (dout[BOUT-(COUT-1)-1-1] & (|dout[BOUT-(COUT-1)-1-1-1:0])) : dout[BOUT-(COUT-1)-1-1];
        assign dout_cut = {dout[BOUT-1], dout[BOUT-1:BOUT-(COUT-1)-1]} + carry_bit;
    end else if (CUT_METHOD == "CUT") begin
        // �ضϲü�
        assign dout_cut = (dout >> (BOUT - COUT));
    end
endgenerate

/*
*   ������ģ��
*   �������źŽ���N�׻���
*/
generate
    genvar i;
    for (i = 0; i < N; i = i + 1) begin : LOOP
        reg  [BOUT-1:0] inte;             // ÿ���������ļĴ���
        wire [BOUT-1:0] sum;              // ÿ���������������

        if (i == 0) begin
            // ��һ�׻�����������Ϊԭʼ����din
            assign sum = inte + {{(BOUT-BIN){din[BIN-1]}}, din};
        end else begin
            // �����׵Ļ�����������Ϊǰһ�������������
            assign sum = inte + (LOOP[i-1].sum);
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)
                inte <= {(BOUT){1'd0}};   // ��λʱ����
            else if (enable_cic)  // ���enable����
                inte <= sum;
        end    
    end
endgenerate

// ��ȡ���һ�������������
wire [BOUT-1:0] inte_out;
assign inte_out = LOOP[N-1].sum;

/*
*   ��ȡ�߼�
*   ���ݳ�ȡ����R�����������
*/
reg [$clog2(R)-1:0] cnt0;            // ��ȡ������
reg [BOUT-1:0] dec_out;               // ��ȡ����������
assign dval = enable_cic && (cnt0 == (R-1));        // ���������ﵽR-1ʱ��dval�ź�Ϊ�ߣ���ʾ������Ч

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt0    <= 'd0;               // ��λ������
        dec_out <= 'd0;               // ��λ��ȡ����������
    end else if (enable_cic) begin  // ���enable����
        cnt0    <= dval ? 'd0 : cnt0 + 1'd1;
        dec_out <= dval ? inte_out : dec_out;
    end
end

/*
*   ΢����ģ��
*   ����ȡ����źŽ���N�ײ�ִ���
*/
generate
    genvar j;
    for (j = 0; j < N; j = j + 1) begin : LOOP2
        reg  [BOUT-1:0] comb;               // ÿ��΢�����Ĵ���
        wire [BOUT-1:0] sub;                // ÿ��΢�����Ĳ�ֽ��

        if (j == 0) begin
            if (M == 1) begin
                // ����ӳ�Ϊ1�����
                assign sub = dec_out - comb;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        comb <= {(BOUT){1'd0}};   // ��λ΢�����Ĵ���
                    else if (enable_cic && dval)  // ���enable����
                        comb <= dec_out;
                end  
            end else begin
                // ����ӳ�Ϊ2�����
                reg [BOUT-1:0] comb1;
                assign sub = dec_out - comb1;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        comb <= {(BOUT){1'd0}};
                        comb1 <= {(BOUT){1'd0}};
                    end else if (enable_cic && dval) begin  // ���enable����
                        comb <= dec_out;
                        comb1 <= comb;
                    end
                end  
            end
        end else begin
            // ��������΢����
            if (M == 1) begin
                assign sub = LOOP2[j-1].sub - comb;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        comb <= {(BOUT){1'd0}};
                    else if (enable_cic && dval)  // ���enable����
                        comb <= LOOP2[j-1].sub;
                end  
            end else begin
                reg [BOUT-1:0] comb1;
                assign sub = LOOP2[j-1].sub - comb1;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        comb <= {(BOUT){1'd0}};
                        comb1 <= {(BOUT){1'd0}};
                    end else if (enable_cic && dval) begin  // ���enable����
                        comb <= LOOP2[j-1].sub;
                        comb1 <= comb;
                    end
                end  
            end
        end
    end
endgenerate

// ���һ��΢�����������Ϊģ����������
assign dout = LOOP2[N-1].sub;

endmodule
