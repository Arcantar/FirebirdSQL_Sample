 unit SysUtils;

 interface

 type
		Exception = class
		public
			Message: string;
			constructor Create(const AMessage: string);
		end;

 implementation

 { Exception }

 constructor Exception.Create(const AMessage: string);
 begin
		Message := AMessage;
 end;

 end.
