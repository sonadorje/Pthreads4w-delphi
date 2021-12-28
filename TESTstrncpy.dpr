program TESTstrncpy;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils;

type
  size_t = UInt32;

function PreDec(var n : size_t): size_t;
begin
   Dec(n);
   Result := n;

end;

//bionic\libc\upstream-openbsd\lib\libc\string\strncpy.c
function strncpy(dst : PChar;const src : PChar; n : size_t):pchar;
var
  d, s : PChar;
  function IsZero: Boolean;
  begin
     d^ := s^;
     if d^ = #0 then
        Result := True
     else
        Result := False;
      Inc(d);
      Inc(s);
  end;
begin

  if n <> 0 then
  begin
    d := dst;
    s := src;

    repeat


      if IsZero then
      begin

        while PreDec(n) <> 0 do
        begin
          d^ := #0;
          Inc(d);

        end;
        break;

      end;


    until PreDec(n) = 0;

  end;
  Result := (dst);
end;

var
  buf: array[0..50] of Char;
  str, s: PChar;
begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
    str := 'Hello, world!';
    s := strncpy(@buf, str, 5);
    Writeln(buf);
    Writeln(s);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
