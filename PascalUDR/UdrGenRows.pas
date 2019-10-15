unit UdrGenRows;

interface

uses Firebird;

type
	GenRowsInMessage = record
		start: Integer;
		startNull: WordBool;
		end_: Integer;
		endNull: WordBool;
	end;

	GenRowsInMessagePtr = ^GenRowsInMessage;

	GenRowsOutMessage = record
		result: Integer;
		resultNull: WordBool;
	end;

	GenRowsOutMessagePtr = ^GenRowsOutMessage;

	GenRowsResultSet = class(iExternalResultSetImpl)
		procedure dispose(); override;
		function fetch(status: iStatus): Boolean; override;

	public
		inMessage: GenRowsInMessagePtr;
		outMessage: GenRowsOutMessagePtr;
	end;

	GenRowsProcedure = class(iExternalProcedureImpl)
		procedure dispose(); override;

		procedure getCharSet(status: iStatus; context: iExternalContext; name: PAnsiChar;
			nameSize: Cardinal); override;

		function open(status: iStatus; context: iExternalContext; inMsg: Pointer;
			outMsg: Pointer): iExternalResultSet; override;
	end;

	GenRowsFactory = class(iUdrProcedureFactoryImpl)
		procedure dispose(); override;

		procedure setup(status: iStatus; context: iExternalContext; metadata: iRoutineMetadata;
			inBuilder: iMetadataBuilder; outBuilder: iMetadataBuilder); override;

		function newItem(status: iStatus; context: iExternalContext;
			metadata: iRoutineMetadata): iExternalProcedure; override;
	end;

implementation

procedure GenRowsResultSet.dispose();
begin
	destroy;
end;

function GenRowsResultSet.fetch(status: iStatus): Boolean;
begin
	if (outMessage.result >= inMessage.end_) then
		Result := false
	else
	begin
		outMessage.result := outMessage.result + 1;
		Result := true;
	end;
end;


procedure GenRowsProcedure.dispose();
begin
	destroy;
end;

procedure GenRowsProcedure.getCharSet(status: iStatus; context: iExternalContext; name: PAnsiChar;
	nameSize: Cardinal);
begin
end;

function GenRowsProcedure.open(status: iStatus; context: iExternalContext; inMsg: Pointer;
	outMsg: Pointer): iExternalResultSet;
var
	Ret: GenRowsResultSet;
begin
	Ret := GenRowsResultSet.create();
	Ret.inMessage := inMsg;
	Ret.outMessage := outMsg;

	Ret.outMessage.resultNull := false;
	Ret.outMessage.result := Ret.inMessage.start - 1;

	Result := Ret;
end;


procedure GenRowsFactory.dispose();
begin
	destroy;
end;

procedure GenRowsFactory.setup(status: iStatus; context: iExternalContext; metadata: iRoutineMetadata;
	inBuilder: iMetadataBuilder; outBuilder: iMetadataBuilder);
begin
end;

function GenRowsFactory.newItem(status: iStatus; context: iExternalContext;
	metadata: iRoutineMetadata): iExternalProcedure;
begin
	Result := GenRowsProcedure.create;
end;


end.


