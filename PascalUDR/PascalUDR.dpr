library PascalUDR;

uses
  Udr_Init,
  UdrGenRows in 'UdrGenRows.pas';

{
create procedure gen_rows_pascal (
    start_n integer not null,
    end_n integer not null
) returns (
    result integer not null
)
    external name 'pascaludr!gen_rows'
    engine udr;
}

exports firebird_udr_plugin;

end.
