program Test_barrier1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,System.Win.Crtl,
  libc.Types in 'libc.Types.pas',
  pthreads.win in 'pthreads.win.pas';
var
   barrier: pthread_barrier_t = nil;

function main:integer;
begin
  assert(barrier = nil);
  assert(pthread_barrier_init(@barrier, nil, 1) = 0);
  assert(barrier <> nil);
  assert(pthread_barrier_destroy(@barrier) = 0);
  assert(barrier = nil);
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
