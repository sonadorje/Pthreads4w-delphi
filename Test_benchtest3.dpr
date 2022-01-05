program Test_benchtest3;

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
type
  Texp  = procedure(p: Pointer);


var

  g_mx, gate1, gate2  : pthread_mutex_t;
  ma                : pthread_mutexattr_t;
  ox, ox2: old_mutex_t ;
  durationMilliSecs : long;
  running: integer=2;
  one: integer=1;
  zero: integer=0;
  worker: pthread_t ;
  starttime, stoptime :Uint32;
   cs1, cs2: TRTLCRITICALSECTION;

const
  ITERATIONS: Integer =      10000000;

function trylockThread( arg : Pointer):Pointer;
var
  i, j, k : integer;
begin
  j := 0; k := 0;
   
   for i := 0 to ITERATIONS-1 do
   begin

      pthread_mutex_trylock(g_mx);
    //TESTSTOP
      if g_mx.ownerThread.p =  nil  then
         j := i;

   end;
  Result := nil;
end;


function oldTrylockThread( arg : Pointer):Pointer;
var
  i, j, k : integer;
begin
  j := 0; k := 0;

   starttime := GetTickCount;
   for i := 0 to ITERATIONS-1 do
   begin

     old_mutex_trylock(@ox);

   end;
  Result := nil;
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
  if pthread_mutex_lock(g_mx) <> 0 then      Exit;
  if pthread_create(@t, nil, trylockThread, 0) <> 0 then Exit;
  if pthread_join(t, nil) <> 0 then      Exit;
  if pthread_mutex_unlock(g_mx) <> 0 then      Halt(1);
  if pthread_mutex_destroy(g_mx) <> 0 then      Exit;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn( Format('%-45s %15d %15.3f'#10,
          [testNameString,
          durationMilliSecs,
          ( durationMilliSecs * 1E3 / ITERATIONS)]));
end;

procedure dummy_call();
begin
   //nothing
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
  if old_mutex_lock(@ox) <> 0 then exit;
  if pthread_create(@t, nil, oldTrylockThread, 0) <> 0 then exit;
  if pthread_join(t, nil) <> 0 then exit;
  if old_mutex_unlock(@ox) <> 0 then exit;
  if old_mutex_destroy(@ox) <> 0 then exit;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn(Format( '%-45s %15d %15.3f'#10,
      ['Old PT Mutex using a Critical Section (WNT)',
          durationMilliSecs,
          ( durationMilliSecs * 1E3 / ITERATIONS / 4)]));

  starttime := GetTickCount;//__PTW32_FTIME(@currSysTimeStart);
  old_mutex_use := OLD_WIN32MUTEX;
  if old_mutex_init(@ox, nil) <> 0 then
    exit;

  if old_mutex_lock(@ox) <> 0 then
    exit;

  if pthread_create(@t, nil, oldTrylockThread, nil) <> 0 then
    exit;

  if pthread_join(t, Nil) <> 0 then Exit;
  if old_mutex_unlock(@ox) <> 0 then Exit;
  if old_mutex_destroy(@ox) <> 0 then Exit;

  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn( Format('%-45s %15d %15.3f'#10,
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
