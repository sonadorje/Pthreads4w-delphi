program Test_benchtest2;

{$IFDEF FPC}
  {$MODE Delphi}//MacPas}

{$ENDIF}

{$APPTYPE CONSOLE}

{$R *.res}
{$DEFINE __PTW32_MUTEX_TYPES}
uses
{$IFnDEF FPC}
  System.SysUtils,
  System.Win.Crtl,
  Winapi.Windows,
{$ELSE}
  Sysutils,
  windows,
{$ENDIF}
  libc.Types in 'libc.Types.pas',
  pthreads.win in 'pthreads.win.pas';

var
  mx, gate1, gate2: pthread_mutex_t;
  ma: pthread_mutexattr_t;
  ox1, ox2: old_mutex_t;
  durationMilliSecs: long;
  running: integer = 2;
  one: integer = 1;
  zero: integer = 0;
  worker: pthread_t;
  starttime, stoptime: Uint32;
  cs1, cs2: TRTLCRITICALSECTION;


const
  ITERATIONS: Integer = 100000;


function overheadThread(arg: Pointer): Pointer;
begin
  while running > 0 do
  begin
    sched_yield();
  end;

  Exit(nil);
end;

function oldThread(arg: Pointer): Pointer;
begin
  while running > 0 do
  begin
    old_mutex_lock(@ox1);
    old_mutex_lock(@ox2);
    old_mutex_unlock(@ox1);
    sched_yield();
    old_mutex_unlock(@ox2);
  end;

  Exit(nil);
end;

function workerThread(arg: Pointer): Pointer;
begin
  while running > 0 do
  begin
    pthread_mutex_lock(gate1);
    pthread_mutex_lock(gate2);
    pthread_mutex_unlock(gate1);
    sched_yield();
    pthread_mutex_unlock(gate2);
  end;

  Result := nil;
end;

function CSThread(arg: Pointer): Pointer;
begin
  while running > 0 do
  begin
    EnterCriticalSection(cs1);
    EnterCriticalSection(cs2);
    LeaveCriticalSection(cs1);
    sched_yield();
    LeaveCriticalSection(cs2);
  end;

  Result := nil;
end;

procedure runTest(testNameString: Pansichar; mType: integer);
var
  i, j, k: integer;
begin
{$IFDEF __PTW32_MUTEX_TYPES}
  assert(pthread_mutexattr_settype(@ma, mType) = 0);
{$ENDIF}
  assert(pthread_mutex_init(mx, @ma) = 0);

  if pthread_mutex_init(gate1, @ma) <> 0 then
    Exit;
  if pthread_mutex_init(gate2, @ma) <> 0 then
    Exit;
  if pthread_mutex_lock(gate1) <> 0 then
    Exit;
  if pthread_mutex_lock(gate2) <> 0 then
    Exit;
  running := 1;
  if pthread_create(@worker, nil, workerThread, nil) <> 0 then
    Exit;
  //TESTSTART
  j := 0;
  k := 0;
   //__PTW32_FTIME(@currSysTimeStart);
  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    pthread_mutex_unlock(gate1);
    sched_yield();
    pthread_mutex_unlock(gate2);
    pthread_mutex_lock(gate1);
    pthread_mutex_lock(gate2);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;

  running := 0;
  if pthread_mutex_unlock(gate2) <> 0 then
    Exit;
  if pthread_mutex_unlock(gate1) <> 0 then
    Exit;
  if pthread_join(worker, nil) <> 0 then
    Exit;
  if pthread_mutex_destroy(gate2) <> 0 then
    Exit;
  if pthread_mutex_destroy(gate1) <> 0 then
    Exit;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn(Format('%-45s %15d %15.3f'#10, [testNameString, durationMilliSecs, (durationMilliSecs * 1E3 / ITERATIONS / 4)]));
end;

procedure dummy_call();
begin
   //nothing
end;

function main(): integer;
var
  i, k, j: integer;

begin
  i := 0;
  pthread_mutexattr_init(@ma);
  Writeln('=============================================================================');
  WriteLn(Format(#10'Lock plus unlock on an unlocked mutex.'#10'%d iterations'#10#10, [ITERATIONS]));
  Writeln(Format('%-45s %15s %15s'#10, ['Test', 'Total(msec)', 'average(usec)']));
  Writeln('-----------------------------------------------------------------------------');

  running := 1;
  if pthread_create(@worker, nil, overheadThread, Nil) <> 0 then
    exit;
  running := 0;
  if pthread_join(worker, Nil) <> 0 then
    exit;

  InitializeCriticalSection(&cs1);
  InitializeCriticalSection(&cs2);
  EnterCriticalSection(&cs1);
  EnterCriticalSection(&cs2);
  running := 1;
  if pthread_create(@worker, nil, CSThread, nil) <> 0 then
    Exit;
  //TESTSTART
  j := 0;
  k := 0;
  starttime := GetTickCount;
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    LeaveCriticalSection(&cs1);
      //sched_yield();
    LeaveCriticalSection(&cs2);
    EnterCriticalSection(&cs1);
    EnterCriticalSection(&cs2);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  running := 0;
  LeaveCriticalSection(&cs2);
  LeaveCriticalSection(&cs1);
  assert(pthread_join(worker, nil) = 0);
  DeleteCriticalSection(&cs2);
  DeleteCriticalSection(&cs1);
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn(Format('%-45s %15d %15.3f'#10, ['Simple Critical Section', durationMilliSecs, (durationMilliSecs * 1E3 / ITERATIONS / 4)]));

  old_mutex_use := OLD_WIN32CS;
  if old_mutex_init(@ox1, nil) <> 0 then
    exit;
  if old_mutex_init(@ox2, nil) <> 0 then
    exit;
  if old_mutex_lock(@ox1) <> 0 then
    exit;
  if old_mutex_lock(@ox2) <> 0 then
    exit;
  running := 1;
  if pthread_create(@worker, nil, oldThread, nil) <> 0 then
    exit;
  //TESTSTART
  j := 0;
  k := 0;
  starttime := GetTickCount; //__PTW32_FTIME(@currSysTimeStart);
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    old_mutex_unlock(@ox1);
    sched_yield();
    old_mutex_unlock(@ox2);
    old_mutex_lock(@ox1);
    old_mutex_lock(@ox2);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  running := 0;
  if old_mutex_unlock(@ox1) <> 0 then
    exit;
  if old_mutex_unlock(@ox2) <> 0 then
    exit;
  if pthread_join(worker, nil) <> 0 then
    exit;
  if old_mutex_destroy(@ox2) <> 0 then
    exit;
  if old_mutex_destroy(@ox1) <> 0 then
    exit;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn(Format('%-45s %15d %15.3f'#10, ['Old PT Mutex using a Critical Section (WNT)', durationMilliSecs, (durationMilliSecs * 1E3 / ITERATIONS / 4)]));

  old_mutex_use := OLD_WIN32MUTEX;
  if old_mutex_init(@ox1, nil) <> 0 then
    exit;
  if old_mutex_init(@ox2, nil) <> 0 then
    exit;
  if old_mutex_lock(@ox1) <> 0 then
    exit;
  if old_mutex_lock(@ox2) <> 0 then
    exit;
  running := 1;
  if pthread_create(@worker, nil, @oldThread, nil) <> 0 then
    exit;
  //TESTSTART
  j := 0;
  k := 0;
  starttime := GetTickCount; //__PTW32_FTIME(@currSysTimeStart);
  for i := 0 to ITERATIONS - 1 do
  begin
    Inc(j);
    k := old_mutex_unlock(@ox1);
    sched_yield();
    k := old_mutex_unlock(@ox2);
    k := old_mutex_lock(@ox1);
    k := old_mutex_lock(@ox2);
  //TESTSTOP
    if (j + k = i) then
      Inc(j);
  end;
  running := 0;
  if old_mutex_unlock(@ox1) <> 0 then
    exit;
  if old_mutex_unlock(@ox2) <> 0 then
    exit;
  if pthread_join(worker, nil) <> 0 then
    exit;
  if old_mutex_destroy(@ox2) <> 0 then
    exit;
  if old_mutex_destroy(@ox1) <> 0 then
    exit;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  WriteLn(Format('%-45s %15d %15.3f'#10, ['Old PT Mutex using a Win32 Mutex (W9x)', durationMilliSecs, (durationMilliSecs * 1E3 / ITERATIONS / 4)]));
  Writeln('.............................................................................');
{$IFDEF __PTW32_MUTEX_TYPES}
  runTest('PTHREAD_MUTEX_DEFAULT', Int(PTHREAD_MUTEX_DEFAULT));
  runTest('PTHREAD_MUTEX_NORMAL', Int(PTHREAD_MUTEX_NORMAL));
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
  Writeln('=======================================');

  pthread_mutexattr_destroy(@ma);
  one := i;
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

