-- generated by hk416hasu
library IEEE;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
	Port ( 
		CLK     : in STD_LOGIC; -- 时钟信号，切换状态机
		RST     : in STD_LOGIC; -- 复位信号，切换至初始状态机
		INPUT   : in  STD_LOGIC_VECTOR (15 downto 0); -- 输入数据
		OUTPUT  : out STD_LOGIC_VECTOR (15 downto 0); -- 输出数据
		stateCnt: out STD_LOGIC_VECTOR (6  downto 0)  -- state的7段数码管数字
	);
end entity alu;

architecture Behavioral of alu is

	signal state	: integer range 0 to 4;	-- 状态机序号
	signal a, b, y	: std_logic_vector (15 downto 0); -- a b存放输入信号, y用于输出
	signal y_17bits: std_logic_vector (16 downto 0); -- 用于生成flag
	signal opCode	: std_logic_vector (3  downto 0); -- 操作码
	signal cin		: std_logic_vector (15 downto 0); -- carry-in, 用vecotr存储便于后续操作
	signal zF    	: std_logic; -- zero     flag
	signal cF    	: std_logic; -- carry    flag
	signal sF    	: std_logic; -- sign  	 flag
	signal overF 	: std_logic; -- overflow flag
	signal cout  	: std_logic; -- carry-out, 只是表示加减法运算的最高位进位
	constant zero	: std_logic_vector(15 downto 0) := (others => '0'); -- 常量0

begin

process(RST, CLK)
begin
	if RST = '0' then 
		state <= 0; a <= (others=>'0'); b <= (others=>'0'); opCode <= (others=>'0'); 
		output <= (others=>'0'); stateCnt <= (others=>'1'); cin    <= (others=>'0');
	elsif CLK'event and CLK = '1' then
		case state is
		
			-- if state == 8, then input a
			-- if state == 0, then input b 					(a is stored)
			-- if state == 1, then input opCode and cin 	(b is stored)
			-- if state == 2, then calcuate over 			(y is ready)
			-- if state == 3, then output y
			-- if state == 4, then output Flags and input a
			
			when 0 => state <= 1; stateCnt <= not "1000000";
				-- if (INPUT /= zero) then a <= INPUT; end if;	-- 只在input有效(不为0)时更新a值
				a <= input;
				OUTPUT <= (others=>'0');
			when 1 => state <= 2; stateCnt <= not "1111001";
				-- if (INPUT /= zero) then b <= INPUT; end if;	-- 只在input有效(不为0)时更新b值
				b <= input;
				OUTPUT <= a;
			when 2 => state <= 3; stateCnt <= not "0100100";
				cin <= (0=>input(15), others=>'0'); opCode <= input(3 downto 0); 
				OUTPUT <= b;
			when 3 => state <= 4; stateCnt <= not "0110000";
				OUTPUT <= y;
			when 4 => state <= 0; stateCnt <= not "0011001";
				OUTPUT <= (0=>cF, 1=>sF, 2=>overF, 3=>zF, 4=>cout, others=>'0');
				
		end case;
	end if;
end process;
	
process(RST, opCode)	
	
	variable b_val	: unsigned(15 downto 0); -- b的无符号数值
	
begin
	cF <= '0'; sF <= '0'; zF <= '0'; overF <= '0'; cout <= '0'; -- 清空标志位, 需要清空么?
	b_val := unsigned(b); -- should be updated here
	
	case opCode is
		-- 为什么不根据y_17bits得到y? 答: 解耦, 更好debug;
		-- 下列标志位设置参考《汇编语言 基于x86处理器》;
		
		-- 加减法影响全部标志位 + 产生Cout
		when "0000"	=> -- Add
			y        <= a + b;
			y_17bits <= ('0' & a) + ('0' & b); -- 仅y(16)是y的最高位进位信号, 其余都不是,下省略注释
			cout     <= y_17bits(16);
			sF       <= y(15);
			cF       <= y_17bits(16) xor '0';
			-- overF <= (a(15) AND b(15) AND (not y(15))) OR ((not a(15)) AND (not b(15)) AND y(15));
			overF    <= (a(15) xnor b(15)) AND (a(15) xor y(15)); -- 仅当a与b’同符号且与y不同时, OF := 1 
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		when "0001"	=> -- Sub
			y        <= a + (not b) + 1; -- a-b可以, 但不可以
			y_17bits <= ('0' & a) + ('0' & (not b)) + 1;
			cout     <= y_17bits(16);
			sF       <= y(15);
			cF       <= y_17bits(16) xor '1';
			-- overF <= (a(15) AND (not b(15)) AND (not y(15))) OR ((not a(15)) AND b(15) AND y(15));
			overF    <= (a(15) xnor (not b(15))) AND (a(15) xor y(15));
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		when "0010"	=> -- ADC
			y        <= a + b + cin;
			y_17bits <= ('0' & a) + ('0' & b) + ('0' & cin);
			cout     <= y_17bits(16);
			sF       <= y(15);
			cF       <= y_17bits(16) xor '0';
			overF    <= (a(15) xnor b(15)) AND (a(15) xor y(15));
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		when "0011"	=> -- SBB (生成标志位时, 按数值减去cin, cf = ~cout)
			y        <= a + (not b) + 1 + (not cin) + 1;
			y_17bits <= ('0' & a) + ('0' & (not b)) + 1 - ('0' & cin); -- '-'运算符会转换为整数来做减法
			cout     <= y_17bits(16);
			sF       <= y(15);
			cF       <= y_17bits(16) xor '1'; -- cf = not cout
			overF    <= (a(15) xnor (not b(15))) AND (a(15) xor y(15));
			if y = zero then zF <= '1'; else zF <= '0'; end if;
		
		when "0100" => -- SBB (生成标志位时, 按补码减去cin, cf = cout, cout是第16位（比如0-0-0的cout是0，第17位弃之）)
			y        <= a + (not b) + 1 + (not cin) + 1;
			y_17bits <= ('0' & a) + ('0' & (not b)) + 1 + ('0' & (not cin)) + 1; -- 按补码减去cin
			cout     <= y_17bits(16);
			sF       <= y(15);
			cF       <= cout;
			overF    <= (a(15) xnor (not b(15))) AND (a(15) xor y(15));
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		-- 逻辑运算影响一部分标志位 ( SF, ZF )
		when "0101" => -- AND
			y        <= a AND b;
			sF       <= y(15);
			if y = zero then zF <= '1'; else zF <= '0'; end if;
		when "0110" => -- OR
			y        <= a OR b;
			sF       <= y(15);
			if y = zero then zF <= '1'; else zF <= '0'; end if;
		when "0111" => -- XOR
			y        <= a xor b;
			sF       <= y(15);
			if y = zero then zF <= '1'; else zF <= '0'; end if;
		when "1000" => -- not
			y        <= not a; -- not运算不影响标志位
		
		-- 逻辑/算数移位运算影响所有标志位
		when "1001" => -- SLL
			y        <= to_stdlogicvector(to_bitvector(a) 		sll to_integer(b_val));
			y_17bits <= to_stdlogicvector(to_bitvector('0' & a) sll to_integer(b_val)); -- y(17)就是cF位
			cF       <= y_17bits(16); -- 逻辑左移中, 最高位移入CF
			sF       <= y(15);
			overF    <= a(15) xor y(15); -- 若移位前后标志位不同, 则溢出
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		when "1010" => -- SRL
			y        <= to_stdlogicvector(to_bitvector(a) 		srl to_integer(b_val));
			y_17bits <= to_stdlogicvector(to_bitvector(a & '0') srl to_integer(b_val)); -- y(0)是cF位
			cF       <= y_17bits(0); -- 逻辑右移中, 最低位移入CF
			sF       <= y(15);
			overF    <= a(15) xor y(15);
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		when "1011" => -- SLA
			y        <= to_stdlogicvector(to_bitvector(a) 		sll to_integer(b_val));
			y_17bits <= to_stdlogicvector(to_bitvector('0' & a) sll to_integer(b_val));
			cF       <= y_17bits(16);
			sF       <= y(15);
			overF    <= a(15) xor y(15);
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		when "1100" => -- SRA
			y        <= to_stdlogicvector(to_bitvector(a) 		sra to_integer(b_val));
			y_17bits <= to_stdlogicvector(to_bitvector(a & '0') sra to_integer(b_val));
			cF       <= y_17bits(0);
			sF       <= y(15);
			overF    <= a(15) xor y(15);
			if y = zero then zF <= '1'; else zF <= '0'; end if;
			
		-- 逻辑循环移位影响部分标志位 ( CF, OF )
		when "1101" => -- ROL
			y        <= to_stdlogicvector(to_bitvector(a) rol to_integer(b_val));
			cf       <= y(0); -- 循环左移中, 最高位移入最低位, 同时移入CF
			overF    <= a(15) xor y(15);
			
		when "1110" => -- ROR
			y        <= to_stdlogicvector(to_bitvector(a) ror to_integer(b_val));	
			cf       <= y(15);
			overF    <= a(15) xor y(15);

		when "1111" => -- pass
			y        <= a;
		
		when others => y <= (others => '0');
			
	end case;
	
	-- sF <= y(15); -- 有些运算不影响sF, 故而为每个运算单独设置
	
end process;

end Behavioral;