program Test_benchtest4;

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

  g_mx  : pthread_mutex_t;
  ma                : pthread_mutexattr_t;
  ox: old_mutex_t ;
  durationMilliSecs : long;
  starttime, stoptime :Uint32;


const
  ITERATIONS: Integer =      10000000;

procedure oldRunTest( testNameString : Pchar; mType : integer);
begin

end;


procedure runTest( testNameString : Pansichar; mType : integer);
var
  i, j, k : integer;
  t: pthread_t;
begin
   starttime := GetTickCount;
{$IFDEF __PTW32_MUTEX_TYPES}
  if pthread_mutexattr_settype(@ma, mType) <> 0 then
     Exit;
{$ENDIF}
  if pthread_mutex_init(g_mx, @ma) <> 0 then      Exit;

  j := 0;
  k := 0;

  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    pthread_mutex_trylock(g_mx);
    pthread_mutex_unlock(g_mx);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  pthread_mutex_destroy(&g_mx);
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
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
  starttime := GetTickCount;
  pthread_mutexattr_init(@ma);
  Writeln('=============================================================================');
  WriteLn( Format(#10'Trylock on a locked mutex.'#10'%d iterations'#10#10,
          [ITERATIONS]));
  Writeln(Format( '%-45s %15s %15s'#10,
      ['Test',
      'Total(msec)',
      'average(usec)']));
  Writeln('-----------------------------------------------------------------------------');
  old_mutex_use := OLD_WIN32CS;
  if old_mutex_init(@ox, nil) <> 0 then exit;

  j := 0;  k := 0;
  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    old_mutex_trylock(@ox);
    old_mutex_unlock(@ox);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;

  if old_mutex_destroy(@ox) <> 0 then exit;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn(Format( '%-45s %15d %15.3f'#10,
      ['Old PT Mutex using a Critical Section (WNT)',
          durationMilliSecs,
          ( durationMilliSecs * 1E3 / ITERATIONS / 4)]));

  //2nd
  old_mutex_use := OLD_WIN32MUTEX;
  assert(old_mutex_init(@ox, Nil) = 0);
  j := 0;  k := 0;
  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    old_mutex_trylock(@ox);
    old_mutex_unlock(@ox);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;

  if old_mutex_destroy(@ox) <> 0 then exit;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn(Format( '%-45s %15d %15.3f'#10,
      ['Old PT Mutex using a Win32 Mutex (W9x)',
          durationMilliSecs,
          ( durationMilliSecs * 1E3 / ITERATIONS / 4)]));
  Writeln('.............................................................................');
{$IFDEF __PTW32_MUTEX_TYPES}
  //runTest('PTHREAD_MUTEX_DEFAULT', Int(PTHREAD_MUTEX_DEFAULT));
  //runTest('PTHREAD_MUTEX_NORMAL', Int(PTHREAD_MUTEX_NORMAL));
  runTest('PTHREAD_MUTEX_ERRORCHECK', Int(PTHREAD_MUTEX_ERRORCHECK));
  runTest('PTHREAD_MUTEX_RECURSIVE', Int(PTHREAD_MUTEX_RECURSIVE));
{$ELSE}
  runTest('Non-blocking lock', 0);
{$ENDIF}
  Writeln('.............................................................................');
  pthread_mutexattr_setrobust(@ma, Int(PTHREAD_MUTEX_ROBUST));
{$IFDEF __PTW32_MUTEX_TYPES}
  runTest('PTHREAD_MUTEX_DEFAULT (Robust)', Int(PTHREAD_MUTEX_DEFAULT));
  runTest('PTHREAD_MUTEX_NORMAL (Robust)', Int(PTHREAD_MUTEX_NORMAL));
  runTest('PTHREAD_MUTEX_ERRORCHECK (Robust)', Int(PTHREAD_MUTEX_ERRORCHECK));
  runTest('PTHREAD_MUTEX_RECURSIVE (Robust)', Int(PTHREAD_MUTEX_RECURSIVE));
{$ELSE}
  runTest('Non-blocking lock', 0);
{$ENDIF}
  Writeln('=============================================================================');

  pthread_mutexattr_destroy(@ma);

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
