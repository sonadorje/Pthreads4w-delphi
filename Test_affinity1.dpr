program Test_affinity1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,System.Win.Crtl,
  libc.Types in 'libc.Types.pas',
  pthreads.win in 'pthreads.win.pas';

function main:integer;
var
  cpu      : uint32;
  newmask,
  src1mask,
  src2mask,
  src3mask : cpu_set_t;
begin
  CPU_ZERO(@newmask);
  CPU_ZERO(@src1mask);
  memset(src2mask, 0, sizeof(cpu_set_t));
  assert(memcmp(@src1mask, @src2mask, sizeof(cpu_set_t)) = 0);
  assert(CPU_EQUAL(@src1mask, @src2mask));
  assert(CPU_COUNT(@src1mask) = 0);
  CPU_ZERO(@src1mask);
  CPU_ZERO(@src2mask);
  CPU_ZERO(@src3mask);
  cpu := 0;
  while ( cpu < sizeof(cpu_set_t)*8) do
  begin
    CPU_SET(cpu, @src1mask);
    cpu := cpu+2;
  end;

  for cpu := 0 to sizeof(cpu_set_t)*4-1 do
  begin
     CPU_SET(cpu, @src2mask);
  end;

  cpu := sizeof(cpu_set_t)*4;
  while ( cpu < sizeof(cpu_set_t)*8) do
  begin
    CPU_SET(cpu, @src2mask);
    cpu := cpu + 2;
  end;
  cpu := 0;
  while ( cpu < sizeof(cpu_set_t)*8) do
  begin
    CPU_SET(cpu, @src3mask);
    cpu := cpu+2;
  end;
  assert(CPU_COUNT(@src1mask) = (sizeof(cpu_set_t)*4));
  assert(CPU_COUNT(@src2mask) = ((sizeof(cpu_set_t)*4 + (sizeof(cpu_set_t)*2))));
  assert(CPU_COUNT(@src3mask) = (sizeof(cpu_set_t)*4));
  CPU_SET(0, @newmask);
  CPU_SET(1, @newmask);
  CPU_SET(3, @newmask);
  assert(CPU_ISSET(1, @newmask));
  CPU_CLR(1, @newmask);
  assert( not CPU_ISSET(1, @newmask));
  CPU_OR(@newmask, @src1mask, @src2mask);
  assert(CPU_EQUAL(@newmask, @src2mask));
  CPU_AND(@newmask, @src1mask, @src2mask);
  assert(CPU_EQUAL(@newmask, @src1mask));
  CPU_XOR(@newmask, @src1mask, @src3mask);
  memset(src2mask, 0, sizeof(cpu_set_t));
  assert(memcmp(@newmask, @src2mask, sizeof(cpu_set_t)) = 0);

  CPU_ZERO(@src1mask);
  cpu := 1;
  while (cpu < sizeof(cpu_set_t)*8) do
  begin
    CPU_SET(cpu, @src1mask);
    cpu := cpu+2;
  end;
  assert(CPU_ISSET(sizeof(cpu_set_t)*8-1, @src1mask));
  assert(CPU_COUNT(@src1mask) = (sizeof(cpu_set_t)*4));
  Result := 0;
end;

begin
  try
    main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
