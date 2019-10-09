program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
	System.SysUtils,
	System.Classes , //only for BinToHex !
	firebird;

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

	FBSockException = class(Exception);

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
	 ftype, fsub, flenght, foffset, fnull : smallint;
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
		 encode : Tencoding;


function isc_blob_info(var status: IStatus; var blob: THandle; itemCount: SmallInt; items: PAnsiChar; bufferLen: SmallInt; buffer: PAnsiChar): Integer; stdcall; external 'fbclient' delayed;

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
	isnull, reelLength : word;
	len : cardinal;
	WordByte:array[0..1]of byte;
	tmpStr : AnsiString;
	tmpD   : double;
	tmpI64 : Int64;
	fISC_QUAD : ISC_QUAD;
	pISC_QUAD : ISC_QUADptr;
	cc : integer;
	segBuff : tbytes;
	segBuffptr : ^TByteArray;
	FBDate : ISC_DATE;
	year, month, day: Cardinal;
	pyear, pmonth, pday: CardinalPtr;
	Lstr2 : string;
 begin

		 Write(format('%s: ', [fname]));
		 move(buf[fnull],WordByte[0],2);
		 isnull := word(WordByte);
		 if isnull<>0 then begin
			Writeln('<Null>');
			exit;
		 end;

		 blob := nil;
		 case ftype of
			 SQL_TEXT     : begin
												Writeln(format(' %s ',[trim(encode.GetString(buf,foffset,flenght))]));
												exit;
											end;
			 SQL_VARYING  : begin
												move(buf[foffset],WordByte[0],2);
												Writeln(format(' %s ',[encode.GetString(buf,foffset+2,word(WordByte))]));
												exit;
											end;
			 SQL_SHORT    : begin
												move(buf[foffset],WordByte[0],2);
												Writeln(format(' %d ',[word(WordByte)]));
												exit;
											end;
			 SQL_DOUBLE   : begin
												move(buf[foffset],tmpD,SizeOf(Double));
												Writeln(format(' %f ',[tmpD]));
												exit;
											end;
			 SQL_LONG     : begin
												move(buf[foffset],tmpI64,SizeOf(int64));
												Writeln(format(' %d ',[tmpI64]));
												exit;
											end;
			 SQL_TYPE_DATE: begin
												move(buf[foffset],FBDate,SizeOf(ISC_DATE));
												pyear := @year; pmonth := @month; pday:=@day;
												util.decodeDate(FBDate, pyear, pmonth, pday);
												Writeln(format(' %d/%d/%d ',[day,month,year]));
												exit;
											end;
			 SQL_BLOB     : begin
												try
												setlength(segBuff,1001);
												move(buf[foffset],fISC_QUAD,sizeof(ISC_QUAD));
												pISC_QUAD := @fISC_QUAD;
												segBuffptr := @segBuff[0];
												blob := att.openBlob(st, tra,pISC_QUAD, 0, nil);
												len := 0;
												if fsub = 1 then
													write(' ') else
													write(' x''');
												repeat
													cc := blob.getSegment(st,1000,segBuffptr,@len);
													if fsub = 1 then
														write(format(' %s ',[trim(encode.GetString(segBuff,0,len)).Replace(#$D,'').replace(#13#10,'')]))
													else begin
														SetLength(LStr2, len * 4);
														BinToHex(segBuff[0], PWideChar(LStr2), len * SizeOf(Char));
														write(LStr2);
													end;
												until cc<>st.RESULT_SEGMENT;
												blob.close(st);
												blob := nil;
												if fsub = 1 then
													Writeln(' ') else
													Writeln(''' ');
												except on e:fbexception do begin
													if assigned(blob) then
														blob.release;
												end;
											 end;
											end;
			 else write(format(' benquéksaissadonc type: %d sub: %d ',[ ftype, fsub ]))
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
	raise FBSockException.create(concat(outMessage,#13#10,fmessage));
	StrDispose(outMessage);
end;

begin
	try
	encode := TEncoding.ANSI;
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
		sql := 'select * from rdb$relations where RDB$RELATION_ID < 3 or RDB$VIEW_SOURCE is not null';
		rs := att.openCursor(st, tra, 0, PAnsiChar(sql), 3, nil, 0, nil, 0, 0);
		inMetadata := rs.getMetadata(st);
		cols := inMetadata.getCount(st);
		setlength(fields,cols);
		f := 0;
		for j:=0 to cols-1 do begin

			t   := inMetadata.getType(st, j);
			sub := inMetadata.getSubType(st, j);

			case t of
			SQL_BLOB : begin
									// if (sub <> 1) then
									//	 continue;
									 //break;
								 end;

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
			fields[f].flenght := inmetadata.getLength(st, j);
			fields[f].foffset := inmetadata.getOffset(st, j);
			fields[f].fnull   := inmetadata.getNullOffset(st, j);

			inc(f);
			if f = cols-1 then
			break;
		end;
		l := inmetadata.getMessageLength(st)+1;
		setlength(buffer ,l);
		outBufferptr := @Buffer[0];
		while (rs.fetchNext(st, outBufferptr) = Integer(0)) do begin
		Writeln('< ');
			for j:=0 to f-1 do
			// call field's function to print it
				fields[j].print(st, att, tra, buffer);
			Writeln(' />'+#13#10);
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
