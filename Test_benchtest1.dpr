program Test_benchtest1;

{$APPTYPE CONSOLE}

{$R *.res}
{$DEFINE __PTW32_MUTEX_TYPES}
uses
  System.SysUtils,System.Win.Crtl,
  Winapi.Windows,
  libc.Types in 'libc.Types.pas',
  pthreads.win in 'pthreads.win.pas';
type
  Texp  = procedure(p: Pointer);

var

  mx                : pthread_mutex_t;
  ma                : pthread_mutexattr_t;
  currSysTimeStart,
  currSysTimeStop   : __PTW32_STRUCT_TIMEB;
  durationMilliSecs : long;
  two: integer=2;
  one: integer=1;
  zero: integer=0;

  starttime, stoptime :Uint32;
const
  ITERATIONS: Integer =      10000000;

 function GetDurationMilliSecs(_TStart, _TStop: __PTW32_STRUCT_TIMEB): Integer;
 begin
    Result := long((_TStop.time*1000+_TStop.millitm)
                    - (_TStart.time*1000+_TStart.millitm)) ;
 end;

procedure runTest( testNameString : Pansichar; mType : integer);
var
  i, j, k : integer;
begin
{$IFDEF __PTW32_MUTEX_TYPES}
  assert(pthread_mutexattr_settype(@ma, mType) = 0);
{$ENDIF}
  assert(pthread_mutex_init(@mx, @ma) = 0);
  //TESTSTART
  j := 0; k := 0;
   //__PTW32_FTIME(@currSysTimeStart);
   starttime := GetTickCount;
   for i := 0 to ITERATIONS-1 do
   begin
      Inc(j);
      pthread_mutex_lock(@mx);
      pthread_mutex_unlock(@mx);
//TESTSTOP

      if (j + k = i) then
        Inc(j);
   end;
   //__PTW32_FTIME(@currSysTimeStop);
  stoptime := GetTickCount;
  assert(pthread_mutex_destroy(@mx) = 0);
  durationMilliSecs := stoptime - starttime;
  //GetDurationMilliSecs(currSysTimeStart, currSysTimeStop) - overHeadMilliSecs;
  printf( '%-45s %15ld %15.3f'#10,
          testNameString,
          durationMilliSecs,
          float( durationMilliSecs * 1E3 / ITERATIONS));
end;

procedure dummy_call();
begin
   //nothing
end;

function main():integer;
var
  i, k, j : integer;
  cs : _RTL_CRITICAL_SECTION;
  //ox : old_mutex_t;
begin
  i := 0;
  pthread_mutexattr_init(@ma);
  Writeln('=============================================================================');
  printf( #10'Lock plus unlock on an unlocked mutex.'#10'%ld iterations'#10#10,
          ITERATIONS);
  Writeln(Format( '%-45s %15s %15s'#10,
      ['Test',
      'Total(msec)',
      'average(usec)']));
  Writeln('-----------------------------------------------------------------------------');


  //TESTSTART
  j := 0; k := 0;
   starttime := GetTickCount;//__PTW32_FTIME(@currSysTimeStart);
   for i := 0 to ITERATIONS-1 do
   begin
      Inc(j);
      dummy_call();
      dummy_call();
  //TESTSTOP
      //__PTW32_FTIME(@currSysTimeStop);
      if (j + k = i) then
        Inc(j);
   end;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  //GetDurationMilliSecs(currSysTimeStart, currSysTimeStop) - overHeadMilliSecs;
  Writeln(Format( '%-45s %15d %15.3f',
      ['Dummy call x 2',
          durationMilliSecs,
          float(durationMilliSecs * 1E3 / ITERATIONS)]));
  //TESTSTART
  j := 0; k := 0;
   starttime := GetTickCount;//__PTW32_FTIME(@currSysTimeStart);
   for i := 0 to ITERATIONS-1 do
   begin
      Inc(j);
      interlocked_inc_with_conditionals(@i);
      interlocked_dec_with_conditionals(@i);
  //TESTSTOP

      if (j + k = i) then
        Inc(j);
   end;
   stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  Writeln(Format( '%-45s %15d %15.3f',
      ['Dummy call . Interlocked with cond x 2',
          durationMilliSecs,
          float( durationMilliSecs * 1E3 / ITERATIONS)]));
  //TESTSTART
  j := 0; k := 0;
   starttime := GetTickCount;//__PTW32_FTIME(@currSysTimeStart);
   for i := 0 to ITERATIONS-1 do
   begin
      Inc(j);
      InterlockedIncrement(i);
      InterlockedDecrement(i);
  //TESTSTOP

      if (j + k = i) then
        Inc(j);
   end;
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  Writeln(Format( '%-45s %15d %15.3f',
      ['InterlockedOp x 2',
          durationMilliSecs,
          float( durationMilliSecs * 1E3 / ITERATIONS)]));

  InitializeCriticalSection(cs);
  //TESTSTART
  j := 0; k := 0;
   starttime := GetTickCount;//__PTW32_FTIME(@currSysTimeStart);
   for i := 0 to ITERATIONS-1 do
   begin
      Inc(j);
      //assert((EnterCriticalSection(@cs), 1) = one);
      EnterCriticalSection(cs);
      //assert((LeaveCriticalSection(@cs), 2) = two);
      LeaveCriticalSection(cs);
  //TESTSTOP

      if (j + k = i) then
        Inc(j);
   end;
  DeleteCriticalSection(cs);
  stoptime := GetTickCount;
  durationMilliSecs := stoptime - starttime;
  Writeln(Format( '%-45s %15d %15.3f',
      ['Simple Critical Section',
          durationMilliSecs,
          float( durationMilliSecs * 1E3 / ITERATIONS)]));
  {old_mutex_use := OLD_WIN32CS;
  assert(old_mutex_init(@ox, nil) = 0);
  TESTSTART
  assert(old_mutex_lock(@ox) = zero);
  assert(old_mutex_unlock(@ox) = zero);
  TESTSTOP
  assert(old_mutex_destroy(@ox) = 0);
  durationMilliSecs := GetDurationMilliSecs(currSysTimeStart, currSysTimeStop) - overHeadMilliSecs;
  printf( '%-45s %15ld %15.3f#10',
      'Old PT Mutex using a Critical Section (WNT)',
          durationMilliSecs,
          (float) durationMilliSecs * 1E3 / ITERATIONS);
  old_mutex_use := OLD_WIN32MUTEX;
  assert(old_mutex_init(@ox, nil) = 0);
  TESTSTART
  assert(old_mutex_lock(@ox) = zero);
  assert(old_mutex_unlock(@ox) = zero);
  TESTSTOP
  assert(old_mutex_destroy(@ox) = 0);
  durationMilliSecs := GetDurationMilliSecs(currSysTimeStart, currSysTimeStop) - overHeadMilliSecs;
  printf( '%-45s %15ld %15.3f#10',
      'Old PT Mutex using a Win32 Mutex (W9x)',
          durationMilliSecs,
          (float) durationMilliSecs * 1E3 / ITERATIONS);
  Writeln('.............................................................................');
  }
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
