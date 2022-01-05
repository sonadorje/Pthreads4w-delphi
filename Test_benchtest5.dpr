program Test_benchtest5;

{$IFDEF FPC}
  {$MODE Delphi}//MacPas}

{$ENDIF}

{$APPTYPE CONSOLE}

{$R *.res}
{$DEFINE __PTW32_MUTEX_TYPES}
uses
{$IFnDEF FPC}
  System.SysUtils, System.Win.Crtl, Winapi.Windows,
{$ELSE}
  Sysutils, windows,
{$ENDIF}
  libc.Types in 'libc.Types.pas',
  pthreads.win in 'pthreads.win.pas';

var

  g_mx, gate1, gate2  : pthread_mutex_t;
  ma                : pthread_mutexattr_t;
  durationMilliSecs : long;
  starttime, stoptime :Uint32;
  sema : sem_t;
  w32sema : THANDLE;

const
  ITERATIONS: Integer =      100*10000;


procedure reportTest( testNameString : Pansichar);
begin
   WriteLn( Format('%-45s %15d %15.3f'#10,
          [testNameString,
          durationMilliSecs,
          ( durationMilliSecs * 1E3 / ITERATIONS)]));
end;

function main():integer;
var
  i, k, j : integer;
  t: pthread_t;
begin

  pthread_mutexattr_init(@ma);
  Writeln('=============================================================================');
  WriteLn( Format(#10'Operations on a semaphore.'#10'%d iterations'#10#10,
          [ITERATIONS]));
  Writeln(Format( '%-45s %15s %15s'#10,
      ['Test',
      'Total(msec)',
      'average(usec)']));
  Writeln('-----------------------------------------------------------------------------');

  w32sema := CreateSemaphore(nil,  0,  ITERATIONS, nil);
  assert(w32sema <> 0);
  starttime := GetTickCount;
   for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    assert(ReleaseSemaphore(w32sema, 1, nil));
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  assert(CloseHandle(w32sema));
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  reportTest('W32 Post with no waiters');

  w32sema := CreateSemaphore(nil,  ITERATIONS,  ITERATIONS, nil);
  assert(w32sema <> 0);
  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    assert(WaitForSingleObject(w32sema, INFINITE) = 0 );
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  assert(CloseHandle(w32sema));
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  reportTest('W32 Wait without blocking');


  assert(sem_init(@sema, 0, 0) = 0);
  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    assert(sem_post(@sema)=0);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  assert(sem_destroy(@sema) = 0);
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  reportTest('POSIX Post with no waiters');


  assert(sem_init(@sema, 0, ITERATIONS) = 0);
  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    assert(sem_wait(@sema) = 0);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  assert(sem_destroy(@sema) = 0);
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  reportTest('POSIX Wait without blocking');


  printf( '=======================================\n');
end;

begin
  try
    main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
