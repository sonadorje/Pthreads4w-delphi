program TestPThread;

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
  NUMTHREADS = 4;

var
  threadbag : array[0..(NUMTHREADS + 1)-1] of bag_t;
  pop_count : sharedInt_t;
  go :pthread_barrier_t = nil;

function mythread( arg : Pointer):Pointer;
var

  bag : Pbag_t;

begin
  result := PTHREAD_CANCELED;//Pointer(int(size_t(PTHREAD_CANCELED)) + 1);
  bag := Pbag_t ( arg);
  assert(bag = @threadbag[bag.threadnum]);
  assert(bag.started = 0);
  bag.started := 1;

  assert(pthread_setcancelstate(Int(PTHREAD_CANCEL_ENABLE), nil) = 0);
  assert(pthread_setcanceltype(Int(PTHREAD_CANCEL_ASYNCHRONOUS), nil) = 0);

  bag.count := 0;
  while bag.count < 100 do
  begin
    Sleep (100);Inc(bag.count);
  end;

end;


function main:integer;
var
  _failed,  i : integer;
  t : array[0..(NUMTHREADS + 1)-1] of pthread_t;
  fail : bool;
  result0 : Pointer;
  stderr: string;
  dwMode : DWORD;
begin
  _failed := 0;


  t[0] := pthread_self();
  assert(t[0].p <> nil);

  dwMode := SetErrorMode(SEM_NOGPFAULTERRORBOX);
  SetErrorMode(dwMode or SEM_NOGPFAULTERRORBOX);

  for i := 1 to NUMTHREADS do
  begin
    threadbag[i].started := 0;
    threadbag[i].threadnum := i;
    assert(pthread_create(@t[i], nil, mythread, Addr(threadbag[i])) = 0);
   
  end;

  (*
   * Code to control or manipulate child threads should probably go here.
   *)
  Sleep (NUMTHREADS * 100);

  for i := 1 to NUMTHREADS do
  begin
     assert(pthread_cancel(t[i]) = 0);
   
  end;

  (*
   * Give threads time to complete.
   *)
  Sleep (NUMTHREADS * 100);

  (*
   * Standard check that all threads started.
   *)
  for i := 1 to NUMTHREADS do
  begin

    if  0>= threadbag[i].started then
    begin
      _failed  := _failed  or ( not threadbag[i].started);
      WriteLn(Format('Thread %d: started %d',[i, threadbag[i].started]));
    end;
  end;

  assert(0>=_failed);

  (*
   * Check any results here. Set "failed" and only print output on failure.
   *)
  _failed := 0;
  for i := 1 to NUMTHREADS do
  begin
    fail := Boolean(0);
    result0 := Pointer(0);
    assert(pthread_join(t[i], @result0) = 0);
    fail := (result0 <> PTHREAD_CANCELED);
    if fail then
    begin
      stderr := Format( 'Thread %d: started %d: count %d',
        [i,
        threadbag[i].started,
        threadbag[i].count]);
      //fflush(stderr);
      Writeln(stderr);
    end;
    if (_failed >0 ) or (fail) then
       _failed := 1;
  end;

  assert( not Boolean(_failed));


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
