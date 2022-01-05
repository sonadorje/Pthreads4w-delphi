program Test_cleanup0;

{$IFDEF FPC}
  {$MODE Delphi}//MacPas}
  {$assertions on}
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
  {$ENDIF}
  libc.Types in 'libc.Types.pas',
  pthreads.win in 'pthreads.win.pas',
  pthreads.sem in 'pthreads.sem.pas',
  pthreads.sched in 'pthreads.sched.pas',
  pthreads.barrier in 'pthreads.barrier.pas',
  pthreads.mutex in 'pthreads.mutex.pas',
  pthreads.mutexattr in 'pthreads.mutexattr.pas',
  pthreads.spin in 'pthreads.spin.pas',
  pthreads.attr in 'pthreads.attr.pas',
  pthreads.cond in 'pthreads.cond.pas',
  pthreads.condattr in 'pthreads.condattr.pas',
  pthreads.rwlock in 'pthreads.rwlock.pas',
  pthreads.ptw32 in 'pthreads.ptw32.pas',
  pthreads.oldmutex in 'pthreads.oldmutex.pas',
  pthreads.core in 'pthreads.core.pas',
  pthreads.CPU in 'pthreads.CPU.pas',
  QueueUser_APCEx in 'QueueUser_APCEx.pas';

type
  bag_t = record

    threadnum,
    started,
    count     : integer;
  end;
  Pbag_t = ^bag_t;

  sharedInt_t = record
    i           : integer;
    cs          : TRTLCriticalSection;
  end;
  PsharedInt_t = ^sharedInt_t;

const
  NUMTHREADS = 10;

var
  threadbag : array[0..(NUMTHREADS + 1)-1] of bag_t;
  pop_count : sharedInt_t;


procedure increment_pop_count( arg : Pointer);
var
  sI: PsharedInt_t;
begin
  sI := PsharedInt_t (arg);
  EnterCriticalSection(&sI.cs);
  Inc(sI.i);
  LeaveCriticalSection(&sI.cs);
end;


function mythread( arg : Pointer):Pointer;
var
  result0 :int;
  bag : Pbag_t;
  L_cleanup: ptw32_cleanup_t;
begin
  result0 := 0;
  bag := Pbag_t ( arg);
  assert(bag = @threadbag[bag.threadnum]);
  assert(bag.started = 0);
  bag.started := 1;

  assert(pthread_setcancelstate(Int(PTHREAD_CANCEL_ENABLE), nil) = 0);
  assert(pthread_setcanceltype(Int(PTHREAD_CANCEL_ASYNCHRONOUS), nil) = 0);
  L_cleanup.routine := increment_pop_count;
  L_cleanup.arg := Pointer(@pop_count);
  ptw32_push_cleanup(@L_cleanup, increment_pop_count, Pointer(@pop_count));
  try
     Sleep(100);

  finally
     //if( _execute>0 )then// or (AbnormalTermination()) then
       //L_cleanup.routine( L_cleanup.arg );
     ptw32_pop_cleanup(1);
  end;

  Result := Pointer(size_t(result0));
end;


function main:integer;
var
  _failed,  i : integer;
  t : array[0..(NUMTHREADS + 1)-1] of pthread_t;
  fail : bool;
  result0 : Pointer;
  stderr: string;
begin
  _failed := 0;
  memset(@pop_count, 0, sizeof(sharedInt_t));
  InitializeCriticalSection(&pop_count.cs);
  t[0] := pthread_self();
  assert(t[0].p <> nil);
  for i := 1 to NUMTHREADS do
  begin
    threadbag[i].started := 0;
    threadbag[i].threadnum := i;
    assert(pthread_create(@t[i], nil, mythread, Pointer( @threadbag[i])) = 0);
  end;

  Sleep(500);

  Sleep(NUMTHREADS * 100);

  for i := 1 to NUMTHREADS do
  begin
    if  0>= threadbag[i].started then
    begin
      _failed  := _failed  or ( not threadbag[i].started);
      WriteLn(Format('Thread %d: started %d',[i, threadbag[i].started]));
    end;
  end;

  assert( 0>=_failed);

  _failed := 0;
  for i := 1 to NUMTHREADS do
  begin
    fail := Boolean(0);
    result0 := Pointer(0);
    assert(pthread_join(t[i], @result0) = 0);
    fail := (result0 = PTHREAD_CANCELED);
    if fail then
    begin
      stderr := Format( 'Thread %d: started %d: result %d'#10,
        [i,
        threadbag[i].started,
      int(size_t(result0))]);
      //fflush(stderr);
      Writeln(stderr);
    end;
    if (Boolean(_failed))  or  (fail) then
       _failed := 1
    else
       _failed := 0;
  end;
  assert( not Boolean(_failed));
  assert(pop_count.i = NUMTHREADS);
  DeleteCriticalSection(&pop_count.cs);

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
