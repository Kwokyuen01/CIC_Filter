clear;

% 打开文件并读取数据
fileID = fopen('dout.txt', 'r');            % 打开文件
data = fscanf(fileID, '%f');                % 读取数据（16进制格式）
fclose(fileID);

% 绘制波形图
figure;
plot(data);
xlabel('样本点');
ylabel('幅值');
title('dout.txt 输出波形');
grid on;
