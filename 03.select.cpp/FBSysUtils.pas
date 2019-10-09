 unit FBSysUtils;

 interface

 const
	// From UIB code
	ScaleDivisor: array[-15..-1] of Int64 = (1000000000000000,100000000000000,
    10000000000000,1000000000000,100000000000,10000000000,1000000000,100000000,
		10000000,1000000,100000,10000,1000,100,10);

  CurrencyDivisor: array[-15..-1] of int64 = (100000000000,10000000000,
		1000000000,100000000,10000000,1000000,100000,10000,1000,100,10,1,10,100,
		1000);

	ScaleFormat: array[-15..-1] of string = (
		'0.0##############', '0.0#############', '0.0############', '0.0###########',
		'0.0##########', '0.0#########', '0.0########', '0.0#######', '0.0######',
		'0.0#####', '0.0####', '0.0###', '0.0##', '0.0#', '0.0');

	TwoDigitLookup : packed array[0..99] of array[1..2] of Char =
		('00','01','02','03','04','05','06','07','08','09',
		 '10','11','12','13','14','15','16','17','18','19',
		 '20','21','22','23','24','25','26','27','28','29',
		 '30','31','32','33','34','35','36','37','38','39',
		 '40','41','42','43','44','45','46','47','48','49',
		 '50','51','52','53','54','55','56','57','58','59',
		 '60','61','62','63','64','65','66','67','68','69',
		 '70','71','72','73','74','75','76','77','78','79',
		 '80','81','82','83','84','85','86','87','88','89',
		 '90','91','92','93','94','95','96','97','98','99');


	SQL_TEXT                  =      452;
	SQL_VARYING               =      448;
	SQL_SHORT                 =      500;
	SQL_LONG                  =      496;
	SQL_FLOAT                 =      482;
	SQL_DOUBLE                =      480;
	SQL_D_FLOAT               =      530;
	SQL_TIMESTAMP             =      510;
	SQL_BLOB                  =      520;
	SQL_ARRAY                 =      540;
	SQL_QUAD                  =      550;
	SQL_TYPE_TIME             =      560;
	SQL_TYPE_DATE             =      570;
	SQL_INT64                 =      580;
	SQL_INT128                =    32752;
	SQL_TIMESTAMP_TZ          =    32754;
	SQL_TIME_TZ               =    32756;
	SQL_DEC16                 =    32760;
	SQL_DEC34                 =    32762;
	SQL_BOOLEAN               =    32764;
	SQL_NULL                  =    32766;


 type

		PReal = ^Real;
		DWord = cardinal;
		PDWord = ^DWord;

		Exception = class
		public
			Message: string;
			constructor Create(const AMessage: string);
		end;

 tbytes = Tarray<byte>;

 function BinToHex(var Buffer; BufSize: Integer):AnsiString;
 function VaxInteger(buffer: array of Byte; index: Integer; length: Integer): Integer;
 function BytesToStrLenghtInLine(const Value: TBytes; fStart, fLength : word): AnsiString;
 function xFormatDT(day,month,year, hours, minutes, seconds:word):AnsiString;
 function xFormatI64(v:Uint64):AnsiString;

 implementation

 { Exception }

constructor Exception.Create(const AMessage: string);
 begin
		Message := AMessage;
 end;

procedure AtBinToHex(Buffer: PAnsiChar; Text: PWideChar; BufSize: Integer);
 Const
	B2HConvert: array[0..15] of Byte = (
		$30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $41, $42, $43, $44, $45, $46);
 var
	I: Integer;
 begin
	for I := 0 to BufSize - 1 do
	begin
		Text[0] := WideChar(B2HConvert[Byte(Buffer[I]) shr 4]);
		Text[1] := WideChar(B2HConvert[Byte(Buffer[I]) and $F]);
		Inc(Text, 2);
	end;
 end;

Function BinToHex(var Buffer; BufSize: Integer):AnsiString;
var
	BinStr: string;
 begin
	SetLength(BinStr,BufSize);
	AtBinToHex(@Buffer, PWideChar(BinStr), BufSize);
	result :=BinStr;
 end;

Function VaxInteger(buffer: array of Byte; index: Integer; length: Integer): Integer;
	 var
	newValue: Integer;
	i, shift: Integer;
 begin
	newValue := 0;
	shift := 0;
	i := index;
	while ((length-1) >= 0) do begin
		newValue := newValue + (buffer[i] and 255) shl shift;
		inc(i);
		shift := shift + 8;
	 dec(length);
	end;
	result := newValue;
end;

Function StrToBytes(const Value : AnsiString): TBytes;
begin
	SetLength(Result, Length(Value)*SizeOf(AnsiChar));
	if Length(Result) > 0 then
		Move(Value[1], Result[0], Length(Result));
end;

Function BytesToStr(const Value: TBytes): AnsiString;
begin
	SetLength(Result, Length(Value) div SizeOf(AnsiChar));
	if Length(Result) > 0 then
		Move(Value[0], Result[1], Length(Value));
end;

Function BytesToStrLenghtInLine(const Value: TBytes; fStart, fLength : word): AnsiString;
var
	i : integer;
begin
	if flength<=0 then
	 exit;
	for i :=fStart to fLength do
		case Value[i] of
		byte(#$D),
		byte(#10): Value[i] := byte(' ');
		end;
	SetLength(Result, fLength div SizeOf(AnsiChar));
	Move(Value[fStart], Result[1], fLength);
end;


Function IntToStr32(Value: Cardinal; Negative: Boolean): string;
var
	I, J, K : Cardinal;
	Digits  : Integer;
	P       : PChar;
	NewLen  : Integer;
begin
	I := Value;
	if I >= 10000 then
		if I >= 1000000 then
			if I >= 100000000 then
				Digits := 9 + Ord(I >= 1000000000)
			else
				Digits := 7 + Ord(I >= 10000000)
		else
			Digits := 5 + Ord(I >= 100000)
	else
		if I >= 100 then
			Digits := 3 + Ord(I >= 1000)
		else
			Digits := 1 + Ord(I >= 10);
	NewLen  := Digits + Ord(Negative);
	SetLength(Result, NewLen);
	P := PChar(Result);
	P^ := '-';
	Inc(P, Ord(Negative));
	if Digits > 2 then
		repeat
			J  := I div 100;           {Dividend div 100}
			K  := J * 100;
			K  := I - K;               {Dividend mod 100}
			I  := J;                   {Next Dividend}
			Dec(Digits, 2);
			PDWord(P + Digits)^ := DWord(TwoDigitLookup[K]);
		until Digits <= 2;
	if Digits = 2 then
		PDWord(P+ Digits-2)^ := DWord(TwoDigitLookup[I])
	else
		PChar(P)^ := Char(I or ord('0'));
end;

Function IntToStr64(Value: UInt64; Negative: Boolean): string;
var
	I64, J64, K64      : UInt64;
	I32, J32, K32, L32 : Cardinal;
	Digits             : Byte;
	P                  : PChar;
	NewLen             : Integer;
begin
	{Within Integer Range - Use Faster Integer Version}
	if (Negative and (Value <= High(Integer))) or
		 (not Negative and (Value <= High(Cardinal))) then
		Exit(IntToStr32(Value, Negative));

	I64 := Value;
	if I64 >= 100000000000000 then
		if I64 >= 10000000000000000 then
			if I64 >= 1000000000000000000 then
				if I64 >= 10000000000000000000 then
					Digits := 20
				else
					Digits := 19
			else
				Digits := 17 + Ord(I64 >= 100000000000000000)
		else
			Digits := 15 + Ord(I64 >= 1000000000000000)
	else
		if I64 >= 1000000000000 then
			Digits := 13 + Ord(I64 >= 10000000000000)
		else
			if I64 >= 10000000000 then
				Digits := 11 + Ord(I64 >= 100000000000)
			else
				Digits := 10;
	NewLen  := Digits + Ord(Negative);
	SetLength(Result, NewLen);
	P := PChar(Result);
	P^ := '-';
	Inc(P, Ord(Negative));
	if Digits = 20 then
	begin
		P^ := '1';
		Inc(P);
		Dec(I64, 10000000000000000000);
		Dec(Digits);
	end;
	if Digits > 17 then
	begin {18 or 19 Digits}
		if Digits = 19 then
		begin
			P^ := '0';
			while I64 >= 1000000000000000000 do
			begin
				Dec(I64, 1000000000000000000);
				Inc(P^);
			end;
			Inc(P);
		end;
		P^ := '0';
		while I64 >= 100000000000000000 do
		begin
			Dec(I64, 100000000000000000);
			Inc(P^);
		end;
		Inc(P);
		Digits := 17;
	end;
	J64 := I64 div 100000000;
	K64 := I64 - (J64 * 100000000); {Remainder = 0..99999999}
	I32 := K64;
	J32 := I32 div 100;
	K32 := J32 * 100;
	K32 := I32 - K32;
	PDWord(P + Digits - 2)^ := DWord(TwoDigitLookup[K32]);
	I32 := J32 div 100;
	L32 := I32 * 100;
	L32 := J32 - L32;
	PDWord(P + Digits - 4)^ := DWord(TwoDigitLookup[L32]);
	J32 := I32 div 100;
	K32 := J32 * 100;
	K32 := I32 - K32;
	PDWord(P + Digits - 6)^ := DWord(TwoDigitLookup[K32]);
	PDWord(P + Digits - 8)^ := DWord(TwoDigitLookup[J32]);
	Dec(Digits, 8);
	I32 := J64; {Dividend now Fits within Integer - Use Faster Version}
	if Digits > 2 then
		repeat
			J32 := I32 div 100;
			K32 := J32 * 100;
			K32 := I32 - K32;
			I32 := J32;
			Dec(Digits, 2);
			PDWord(P + Digits)^ := DWord(TwoDigitLookup[K32]);
		until Digits <= 2;
	if Digits = 2 then
		PDWord(P + Digits-2)^ := DWord(TwoDigitLookup[I32])
	else
		P^ := Char(I32 or ord('0'));
end;

Function xFormatDT(day,month,year, hours, minutes, seconds:word):AnsiString;
 Function Int64ToStr(v: UInt64):AnsiString;
 begin
		result := IntToStr32(v,v<0);
 end;
begin
 if hours+minutes+seconds = 0 then
	result := Int64ToStr(day)+'/'+Int64ToStr(month)+'/'+Int64ToStr(year)
 else
	result := Int64ToStr(day)+'/'+Int64ToStr(month)+'/'+Int64ToStr(year)+' '+Int64ToStr(hours)+':'+Int64ToStr(minutes)+':'+Int64ToStr(seconds)
end;

Function xFormatI64(v:Uint64):AnsiString;
begin
	result := 'i64 '+ IntToStr64(v,v<0);
end;

end.
