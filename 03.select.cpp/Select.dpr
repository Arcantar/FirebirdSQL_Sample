program Select;

{$APPTYPE CONSOLE}
{$WEAKLINKRTTI ON}
{$SETPEFLAGS 1}

{$R *.res} //??

uses
	System.SysUtils,
	firebird,
	FBSysUtils in 'FBSysUtils.pas';

type
	MyField = record
		fname : string;
		ftype, fsub, flength, foffset, fnull, fscale, fCharSet : smallint;
		procedure printHeader(f : boolean);
		procedure print(f : boolean; st : IStatus ; att : IAttachment; tra : ITransaction; buf : tbytes);
	end;
var
	// Status is used to return wide error description to user
	st : IStatus;
	// This is main interface of firebird, and the only one
	// for getting which there is special function in our API
	master : IMaster ;

	util   : IUtil;
	// XpbBuilder helps to create various parameter blocks for API calls
	dpb ,tpb : IXpbBuilder;
	// Provider is needed to start to work with database (or service)
	prov : IProvider;
	// Attachment and Transaction contain methods to work with
	// database attachment and transaction
	att : IAttachment;
	tra : ITransaction;
	stmt: IStatement;
	rs: IResultSet;
	// Interfaces provides access to format of data in/out messages
	outMetadata: IMessageMetadata;
	// Interface makes it possible to change format of data or define it yourself
	builder :IMetadataBuilder;
	sql : ansistring;
	cols: smallint;
	fields : array of MyField;
	f, j, l : smallint;
	buffer : tbytes;
	outBufferptr: ^TByteArray;
	blob : iblob;
	SRV, PORT, DBPATH, UNAME, PASS : AnsiString;

procedure MyField.printHeader(f : boolean);
begin
	if f then
		Write(format('"%s"', [fname]))
	else
		Write(format(';"%s"', [fname]))
end;

procedure MyField.print(f:boolean;st: IStatus; att: IAttachment; tra: ITransaction; buf: tbytes);
var
	cc : integer;
	len : cardinal;
	segBuff : tbytes;
	ASQLCode : smallint;
	fStr : string;
	segBuffptr : ^TByteArray;
	year, month, day: Cardinal;
	pyear, pmonth, pday: CardinalPtr;
	hours, minutes, seconds, fractions: Cardinal;
	phours, pminutes, pseconds,pfractions: CardinalPtr;

 begin
	ASQLCode := (ftype and not(1));

	if f then
		fStr :='' else
		fStr :=';';


	if ((pword(@buf[fnull])^=65535)or(SQL_NULL = ASQLCode)) then begin
		Write(fStr+'"<Null>"');
		exit;
	end;



	blob := nil;
	case ASQLCode of
	SQL_TEXT     : begin
					if fCharSet = 1 then begin
						write(fStr+'x'''+BinToHex(buf[foffset], flength * SizeOf(Char))+'''');
					end else
						Write(fStr+'"'+BytesToStrLenghtInLine(buf,foffset,flength)+'"');
					exit;
					end;
	 SQL_VARYING  : begin
						Write(fStr+'"'+BytesToStrLenghtInLine(buf,foffset+2,word(pword(@buf[foffset])^))+'"');
						exit;
					end;
	 SQL_SHORT    : begin
						if FScale < 0 then begin
							Write(fStr+FormatFloat(ScaleFormat[FScale], PSmallInt(@buf[foffset])^ / ScaleDivisor[fScale]));
							exit;
						end;
						write(fStr+inttostr(PSmallInt(@buf[foffset])^));
						exit;
					end;
	 SQL_FLOAT    : begin
							Write(fStr+FloatToStr(PSingle(@buf[foffset])^));
							Exit;
					end;
	 SQL_D_FLOAT,
	 SQL_DOUBLE   : begin
						if FScale < 0 then begin
							FormatFloat(fStr+ScaleFormat[fScale], PDouble(@buf[foffset])^ /ScaleDivisor[fScale]);
							exit;
						end
						else
						if FScale > 0 then begin
							FormatFloat(fStr+ScaleFormat[fScale], PDouble(@buf[foffset])^);
							exit;
						end;
						FormatFloat(fStr+ScaleFormat[fScale], PDouble(@buf[foffset])^);
						exit;
					end;
	 SQL_LONG     : begin
						if FScale<0 then begin
							write(fStr+FormatFloat(ScaleFormat[fScale], PInteger(@buf[foffset])^  / ScaleDivisor[fScale]));
							exit;
						end;
						if FScale>0 then begin
							write(fStr+inttostr(PInteger(@buf[foffset])^  * ScaleDivisor[fScale]));
							exit;
						end;
						write(fStr+inttostr(PInteger(@buf[foffset])^  * ScaleDivisor[fScale]));
						exit;
					end;
	 SQL_TYPE_DATE: begin
						pyear := @year; pmonth := @month; pday:=@day;
						util.decodeDate(PInteger(@buf[foffset])^, pyear, pmonth, pday);
						Write(fStr+xFormatDT(day,month,year, hours, minutes, seconds));
						exit;
					end;
	 SQL_TIMESTAMP: begin
						pyear := @year; pmonth := @month; pday:=@day;
						phours:=@hours ; pminutes:=@minutes; pseconds:=@seconds; pfractions :=@fractions;
						util.decodeDate(ISC_QUADptr(@buf[foffset])^[1], pyear, pmonth, pday);
						util.decodetime(ISC_QUADptr(@buf[foffset])^[2], phours, pminutes, pseconds,pfractions);
						Write(fStr+xFormatDT(day,month,year, hours, minutes, seconds));
						exit;
					end;
	 SQL_INT64    : begin
						if FScale < 0 then begin
							Write(fStr+FormatFloat(ScaleFormat[FScale], pInt64(@buf[foffset])^    / ScaleDivisor[fscale]));
							exit;
						end;
						if FScale > 0 then begin
							Write(fStr+inttostr(pInt64(@buf[foffset])^ * ScaleDivisor[fscale]));
						exit;
						end;
						Write(fStr+inttostr(pInt64(@buf[foffset])^));
						exit;
					end;
	 SQL_ARRAY    : begin
						setlength(segBuff,1001);
						segBuffptr := @segBuff[0];
						// get_slice !! param ??
						blob := att.openBlob(st, tra,@ISC_QUADptr(@buf[foffset])^, 0, nil);
						write(fStr+'x''');
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
							write(fStr+'"') else
							write(fStr+'x''');
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
							Write(fStr+'"') else
							Write(fStr+''' ');
						except on e:fbexception do
							begin
							if assigned(blob) then
								blob.release;
							end;
						end;
					end;
	 SQL_BOOLEAN   :	Write(fStr+BoolToStr(PSmallint(@buf[foffset])^ = 1)) ;

	 SQL_INT128,
	 SQL_TIMESTAMP_TZ,
	 SQL_TIME_TZ,
	 SQL_DEC16,
	 SQL_DEC34    : begin
						Write(fStr+'a little bit later in the year, maybe');
					end
	 else begin
				write(fStr+format(' benquéksaissadonc type: %d sub: %d ',[ ftype, fsub ]))
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
	writeln( concat(outMessage,#13#10,fmessage));
	StrDispose(outMessage);
end;

begin

try
if paramcount=6 then
begin
	SRV    := paramstr(1);
	PORT   := paramstr(2);
	DBPATH := paramstr(3);
	UNAME  := paramstr(4);
	PASS   := paramstr(5);
	SQL    := paramstr(6);
end else begin
	SRV    := 'localhost';
	PORT   := '3050';
	DBPATH := 'employee';
	UNAME  := 'SYSDBA';
	PASS   := 'masterkey';
	SQL    := 'select * from employee e join job j on j.job_code = e.job_code';
end;
except
	on e:exception do
	writeln(e.message);
end;

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
	  dpb.insertString(st, isc_dpb_user_name,  PAnsiChar(UNAME));
	  dpb.insertString(st, isc_dpb_password, PAnsiChar(PASS));
	end;
	// attach employee db
	try
	  att := prov.attachDatabase(st,PAnsiChar(SRV+'/'+PORT+':'+DBPATH), dpb.getBufferLength(st), dpb.getBuffer(st));
	except on e:FBexception do
	  writeln(e.message);
	end;

	// start read only transaction
	tpb := util.getXpbBuilder(st, IXpbBuilder.TPB, nil, 0);
	tpb.insertTag(st, isc_tpb_read_committed);
	tpb.insertTag(st, isc_tpb_no_rec_version);
	tpb.insertTag(st, isc_tpb_wait);
	tpb.insertTag(st, isc_tpb_read);

	tra := att.startTransaction(st, tpb.getBufferLength(st), tpb.getBuffer(st));

	// prepare statement              'select last_name, first_name, phone_ext from phone_list where location = ''Monterey'' order by last_name, first_name'
	stmt := att.prepare(st, tra, 0, PAnsiChar(SQL),
			3, IStatement.PREPARE_PREFETCH_METADATA);

	// get list of columns
	outMetadata := stmt.getOutputMetadata(st);
	builder := outMetadata.getBuilder(st);
	cols := outMetadata.getCount(st);
	setlength(fields,cols);

	f := 0;
	for j:=0 to cols-1 do begin
	  fields[f].ftype    := outMetadata.getType(st, j);
	  fields[f].fsub     := outMetadata.getSubType(st, j);
	  fields[f].fname    :='['+outMetadata.getAlias(st, j)+'] '+ outMetadata.getRelation(st,j)+'.'+outMetadata.getField(st, j);
	  fields[f].flength  := outMetadata.getLength(st, j);
	  fields[f].foffset  := outMetadata.getOffset(st, j);
	  fields[f].fnull    := outMetadata.getNullOffset(st, j);
	  fields[f].fscale   := outMetadata.getScale(st,j);
	  fields[f].fCharSet := outMetadata.getCharSet(st,j);
	  fields[f].printHeader(j=0);
	  inc(f);
	end;
	WriteLn(' ');
	// release automatically created metadata
	// metadata is not database object, therefore no specific call to close it
	outMetadata.release();

	// get metadata with coerced datatypes
	outMetadata := builder.getMetadata(st);

	// builder not needed any more
	builder.release();
	builder := nil;

	// open cursor
	rs := stmt.openCursor(st, tra, nil, nil, outMetadata, 0);

	// allocate output buffer
	l := outMetadata.getMessageLength(st)+1;
	setlength(buffer ,l);
	outBufferptr := @Buffer[0];

	while (rs.fetchNext(st, outBufferptr) = Integer(0)) do begin
	  for j:=0 to f-1 do
	    // call field's function to print it
	    fields[j].print(j=0,st, att, tra, buffer);
	  Writeln(' ');
	end;

	// close interfaces
	rs.close(st);
	rs := nil;

	stmt.free(st);
	stmt := nil;

	outMetadata.release();
	outMetadata := nil;

	tra.commit(st);
	tra := nil;

	att.detach(st);
	att := nil;

except
	on E: FBException do  begin
	  PrintError(e.getStatus,0,e.Message);
	  if assigned(outMetadata) then
		outMetadata.release();
	  outMetadata := nil;

	  if assigned(rs) then
		rs.release;
	  rs := nil;

	  if assigned(stmt) then
		stmt.release();
	  stmt := nil;

	  if assigned(tra) then
		tra.release();
	  tra := nil;

	  if assigned(att) then
		att.detach(st);
	  att := nil;

	  prov.release();
	  st.dispose();

	end;

end;
end.
