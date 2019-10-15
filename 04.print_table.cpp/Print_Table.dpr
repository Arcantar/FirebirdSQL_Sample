program Print_Table;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  firebird,
  FBSysUtils in 'FBSysUtils.pas';

const
 SQL_TEXT = 452; // Array of char
 SQL_VARYING = 448;
 SQL_SHORT = 500;
 SQL_LONG = 496;
 SQL_FLOAT = 482;
 SQL_DOUBLE = 480;
 SQL_D_FLOAT = 530;
 SQL_TIMESTAMP = 510;
 SQL_BLOB = 520;
 SQL_ARRAY = 540;
 SQL_QUAD = 550;
 SQL_TYPE_TIME = 560;
 SQL_TYPE_DATE = 570;
 SQL_INT64 = 580;
 SQL_BOOLEAN = 32764;
 SQL_NULL = 32766;
 SQL_DATE = SQL_TIMESTAMP;

type


	InMessage = record
		n: SmallInt;
		nNull: WordBool;
	end;

	OutMessage = record
		relationId: SmallInt;
		relationIdNull: WordBool;
		relationName: array[0..63] of AnsiChar;
		relationNameNull: WordBool;
	end;

	MyField = record
	 fname : string;
	 ftype, fsub, flength, foffset, fnull, fscale, fCharSet : smallint;
	 procedure print(st : IStatus ; att : IAttachment; tra : ITransaction; buf : tbytes);
	end;

	var
		 // Status is used to return wide error description to user
		 st : IStatus;
		 // This is main interface of firebird, and the only one
		 // for getting which there is special function in our API
		 master : IMaster ;

		 util   : IUtil;
		 // XpbBuilder helps to create various parameter blocks for API calls
		 dpb : IXpbBuilder;
		 // Provider is needed to start to work with database (or service)
		 prov : IProvider;
		 // Attachment and Transaction contain methods to work with
		 // database attachment and transaction
		 att : IAttachment;

		 tra : ITransaction;

		 rs: IResultSet;
		 inMetadata: IMessageMetadata;
		 sql : ansistring;
		 cols: smallint;
		 fields : array of MyField;
		 f, j, t, sub , l : smallint;
		 s : string;
		 buffer : tbytes;
		 outBufferptr: ^TByteArray;
		 blob : iblob;

 function VaxInteger(buffer: array of Byte; index: Integer; length: Integer): Integer;
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

 procedure MyField.print(st: IStatus; att: IAttachment; tra: ITransaction; buf: tbytes);
 var
	cc : integer;
	len : cardinal;
	segBuff : tbytes;
	ASQLCode : smallint;
	segBuffptr : ^TByteArray;
	year, month, day: Cardinal;
	pyear, pmonth, pday: CardinalPtr;
	hours, minutes, seconds, fractions: Cardinal;
	phours, pminutes, pseconds,pfractions: CardinalPtr;
 begin

	ASQLCode := (ftype and not(1));
  Writeln('');
	Write(format('%s: ', [fname]));

	if ((pword(@buf[fnull])^=65535)or(SQL_NULL = ASQLCode)) then begin
		Write('"<Null>"');
		exit;
	end;

	blob := nil;
	case ASQLCode of
	SQL_TEXT     : begin
					if fCharSet = 1 then begin
						write('x'''+BinToHex(buf[foffset], flength * SizeOf(Char))+'''');
					end else
						Write('"'+trim(BytesToStrLenghtInLine(buf,foffset,flength))+'"');
					exit;
					end;
	 SQL_VARYING  : begin
						Write('"'+trim(BytesToStrLenghtInLine(buf,foffset+2,word(pword(@buf[foffset])^)))+'"');
						exit;
					end;
	 SQL_SHORT    : begin
						if FScale < 0 then begin
							Write(FormatFloat(ScaleFormat[FScale], PSmallInt(@buf[foffset])^ / ScaleDivisor[fScale]));
							exit;
						end;
						write(inttostr(PSmallInt(@buf[foffset])^));
						exit;
					end;
	 SQL_FLOAT    : begin
							Write(FloatToStr(PSingle(@buf[foffset])^));
							Exit;
					end;
	 SQL_D_FLOAT,
	 SQL_DOUBLE   : begin
						if FScale < 0 then begin
							FormatFloat(ScaleFormat[fScale], PDouble(@buf[foffset])^ /ScaleDivisor[fScale]);
							exit;
						end
						else
						if FScale > 0 then begin
							FormatFloat(ScaleFormat[fScale], PDouble(@buf[foffset])^);
							exit;
						end;
						FormatFloat(ScaleFormat[fScale], PDouble(@buf[foffset])^);
						exit;
					end;
	 SQL_LONG     : begin
						if FScale<0 then begin
							write(FormatFloat(ScaleFormat[fScale], PInteger(@buf[foffset])^  / ScaleDivisor[fScale]));
							exit;
						end;
						if FScale>0 then begin
							write(inttostr(PInteger(@buf[foffset])^  * ScaleDivisor[fScale]));
							exit;
						end;
						write(inttostr(PInteger(@buf[foffset])^  * ScaleDivisor[fScale]));
						exit;
					end;
	 SQL_TYPE_DATE: begin
						pyear := @year; pmonth := @month; pday:=@day;
						util.decodeDate(PInteger(@buf[foffset])^, pyear, pmonth, pday);
						Write(xFormatDT(day,month,year, hours, minutes, seconds));
						exit;
					end;
	 SQL_TIMESTAMP: begin
						pyear := @year; pmonth := @month; pday:=@day;
						phours:=@hours ; pminutes:=@minutes; pseconds:=@seconds; pfractions :=@fractions;
						util.decodeDate(ISC_QUADptr(@buf[foffset])^[1], pyear, pmonth, pday);
						util.decodetime(ISC_QUADptr(@buf[foffset])^[2], phours, pminutes, pseconds,pfractions);
						Write(xFormatDT(day,month,year, hours, minutes, seconds));
						exit;
					end;
	 SQL_INT64    : begin
						if FScale < 0 then begin
							Write(FormatFloat(ScaleFormat[FScale], pInt64(@buf[foffset])^    / ScaleDivisor[fscale]));
							exit;
						end;
						if FScale > 0 then begin
							Write(inttostr(pInt64(@buf[foffset])^ * ScaleDivisor[fscale]));
						exit;
						end;
						Write(inttostr(pInt64(@buf[foffset])^));
						exit;
					end;
	 SQL_ARRAY    : begin
						setlength(segBuff,1001);
						segBuffptr := @segBuff[0];
						// get_slice !! param ??
						blob := att.openBlob(st, tra,@ISC_QUADptr(@buf[foffset])^, 0, nil);
						write('x''');
						repeat
							cc := blob.getSegment(st,1000,segBuffptr,@len);
							if fsub = 1 then //??? pff
								write(BytesToStrLenghtInLine(segBuff,0,len))
							else begin
								write(BinToHex(segBuff[0], len * SizeOf(Char)));
							end;
						until cc<>st.RESULT_SEGMENT;
						write('''');
						blob.close(st);
						blob := nil;
						 //to do type array ???
					end;
	 SQL_BLOB     : begin
						try
						setlength(segBuff,1001);
						segBuffptr := @segBuff[0];
						blob := att.openBlob(st, tra,@ISC_QUADptr(@buf[foffset])^, 0, nil);
						len := 0;
						if fsub = 1 then
							write('"') else
							write('x''');
						repeat
							cc := blob.getSegment(st,1000,segBuffptr,@len);
							if fsub = 1 then
								write(BytesToStrLenghtInLine(segBuff,0,len))
							else begin
								write(BinToHex(segBuff[0], len * SizeOf(Char)));
							end;
						until cc<>st.RESULT_SEGMENT;
						blob.close(st);
						blob := nil;
						if fsub = 1 then
							Write('"') else
							Write(''' ');
						except on e:fbexception do
							begin
							if assigned(blob) then
								blob.release;
							end;
						end;
					end;
	 SQL_BOOLEAN   :	Write(BoolToStr(PSmallint(@buf[foffset])^ = 1)) ;

	 SQL_INT128,
	 SQL_TIMESTAMP_TZ,
	 SQL_TIME_TZ,
	 SQL_DEC16,
	 SQL_DEC34    : begin
						Write('a little bit later in the year, maybe');
					end
	 else begin
				write(format(' benquéksaissadonc type: %d sub: %d ',[ ftype, fsub ]))
				end;
	end;
 end;

procedure PrintError(s : IStatus; error_num : word; fmessage:string);
var
	maxMessage : Integer;
	outMessage : PAnsiChar;
begin
	maxMessage := 256;
	outMessage := AnsiStrAlloc(maxMessage);
	util.formatStatus(outMessage, maxMessage, s);
	Writeln(concat(outMessage,#13#10,fmessage));
	StrDispose(outMessage);
end;

begin
	try
	if master = nil then
		master := fb_get_master_interface;
	if util = nil then
		util   := master.getUtilInterface;
	if st = nil then
		st     := master.getStatus;
	if prov = nil then
		prov   := master.getDispatcher;
	if dpb = nil then begin
		dpb    := util.getXpbBuilder(st, IXpbBuilder.DPB, nil, 0);
		dpb.insertString(st, isc_dpb_user_name,  'SYSDBA');
		dpb.insertString(st, isc_dpb_password, 'masterkey');
	end;
	try
		att := prov.attachDatabase(st,PAnsiChar('employee'), dpb.getBufferLength(st), dpb.getBuffer(st));
		tra := att.startTransaction(st, 0, nil);

		// If we are not going to run same SELECT query many times we may do not prepare it,
		// opening cursor instead with single API call.
		// If statement has input parameters and we know them, appropriate IMetadata may be
		// constructed and passed to openCursor() together with data buffer.
		// We also may provide out format info and coerce data passing appropriate metadata
		// into API call.
		// In this sample we have no input parameters and do not coerce anything - just
		// print what we get from SQL query.
		sql := 'select * from rdb$relations where RDB$RELATION_ID < 3 or RDB$VIEW_SOURCE is not null';

		// Do not use IStatement - just ask attachment to open cursor
		rs := att.openCursor(st, tra, 0, pAnsiChar(sql), 3, nil, 0, nil, 0, 0);
		inMetadata := rs.getMetadata(st);
		cols := inMetadata.getCount(st);
		setlength(fields,cols);
		f := 0;
		for j:=0 to cols-1 do begin

			t   := inMetadata.getType(st, j);
			sub := inMetadata.getSubType(st, j);

			case t of
			SQL_BLOB,
			SQL_TEXT,
			SQL_VARYING,
			SQL_SHORT,
			SQL_DOUBLE,
			SQL_LONG,
			SQL_TYPE_DATE:		//break;

			else begin
						s := format('Unknown type %d for %s', [ t, inmetadata.getField(st, j)]);
						Writeln(s);
						raise exception.create(s);
					end;
			end;
			// we can work with this field - cache metadata info for fast access
			fields[f].ftype   := t;
			fields[f].fsub		:= sub;
			fields[f].fname   := inmetadata.getField(st, j);
			fields[f].flength := inmetadata.getLength(st, j);
			fields[f].foffset := inmetadata.getOffset(st, j);
			fields[f].fnull   := inmetadata.getNullOffset(st, j);
			fields[f].fscale  := inMetadata.getScale(st,j);
			fields[f].fCharSet:= inMetadata.getCharSet(st,j);

			inc(f);
			if f = cols-1 then
			break;
		end;
		l := inmetadata.getMessageLength(st)+1;
		setlength(buffer ,l);
		outBufferptr := @Buffer[0];

		// fetch records from cursor
		while (rs.fetchNext(st, outBufferptr) = Integer(0)) do begin
		Write('< ');
			for j:=0 to f-1 do
			// call field's function to print it
				fields[j].print(st, att, tra, buffer);
			Write(#13#10+'/>');
		 end;
		readln(s);

		rs.close(st);
		rs := nil;
		if assigned(inmetadata) then
		 inmetadata.release();
		inmetadata := nil;
		if assigned(tra) then
			tra.commit(st);
		tra := nil;

		if assigned(att) then
		 att.detach(st);
		att := nil;

		st.dispose;

	except on e:FBException do
		 PrintError(e.getStatus,0,e.Message);
	end;
	except
		on E: Exception do
			Writeln(E.ClassName, ': ', E.Message);
	end;
end.
