unit pthreads.cond;

interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,

   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

function pthread_cond_init(cond: Ppthread_cond_t; const attr: Ppthread_condattr_t): Integer;
function PTW32_cond_timedwait(cond : Ppthread_cond_t; mutex : Ppthread_mutex_t; abstime : Ptimespec):integer;
function PTW32_cond_check_need_init( cond : Ppthread_cond_t):integer;
function pthread_cond_destroy(cond: Ppthread_cond_t): Integer;

function pthread_cond_wait(cond: Ppthread_cond_t; mutex: Ppthread_mutex_t): Integer;

function pthread_cond_timedwait(cond: Ppthread_cond_t; mutex: Ppthread_mutex_t; const abstime: Ptimespec): Integer;
function pthread_cond_signal(cond: Ppthread_cond_t): Integer;

function pthread_cond_broadcast(cond: Ppthread_cond_t): Integer;

implementation
uses pthreads.ptw32, pthreads.mutex, pthreads.sem;

function pthread_cond_destroy( cond : Ppthread_cond_t):integer;
var
  cv : pthread_cond_t;
  result0, result1, result2, tmp : integer;
  node : PTW32_mcs_local_node_t;
begin
  result0 := 0; result1 := 0; result2 := 0;

  if (cond = nil)  or  (cond^ = nil) then
      Exit(EINVAL);

  if cond^ <> PTHREAD_COND_INITIALIZER then
  begin
      PTW32_mcs_lock_acquire(@g_PTW32_cond_list_lock, @node);
      cv := cond^;

      if PTW32_semwait (@cv.semBlockLock) <> 0  then
      begin
        result0 := PTW32_GET_ERRNO();
      end
      else
      begin
          result0 := pthread_mutex_trylock (cv.mtxUnblockLock);
          if result0  <> 0 then
          begin
            sem_post (@cv.semBlockLock);
          end;
      end;
      if result0 <> 0 then
      begin
          PTW32_mcs_lock_release(@node);
          Exit(result);
      end;

      if cv.nWaitersBlocked > cv.nWaitersGone then
      begin
        if sem_post (@cv.semBlockLock) <> 0 then
          begin
            result := PTW32_GET_ERRNO();
          end;
        result1 := pthread_mutex_unlock (cv.mtxUnblockLock);
        result2 := EBUSY;
      end
      else
      begin

          cond^ := nil;
          if sem_destroy (@cv.semBlockLock ) <> 0  then
             result0 := PTW32_GET_ERRNO();

          if sem_destroy (@cv.semBlockQueue) <> 0 then
             result1 := PTW32_GET_ERRNO();

          result2 := pthread_mutex_unlock (cv.mtxUnblockLock );
          if result2 = 0 then
             result2 := pthread_mutex_destroy (cv.mtxUnblockLock);


          if g_PTW32_cond_list_head = cv then
              g_PTW32_cond_list_head := cv.next

          else
              cv.prev.next := cv.next;

          if g_PTW32_cond_list_tail = cv then
              g_PTW32_cond_list_tail := cv.prev

          else
             cv.next.prev := cv.prev;

          free (cv);
      end;
      PTW32_mcs_lock_release(@node);
  end
  else
  begin

    PTW32_mcs_lock_acquire(@g_PTW32_cond_test_init_lock, @node);

    if cond^ = PTHREAD_COND_INITIALIZER then
       cond^ := nil
    else
      result0 := EBUSY;

      PTW32_mcs_lock_release(@node);
  end;
  if result1 <> 0 then
     tmp := result1
  else
     tmp := result2;
  if (result0 <> 0) then
     Result := result0
  else
     Result := tmp;
end;

function PTW32_cond_unblock( cond : Ppthread_cond_t; unblockAll : integer):integer;
var

  cv              : pthread_cond_t;
  nSignalsToIssue : integer;
begin
  if (cond = nil)  or  (cond^ = nil) then begin
      Exit(EINVAL);
    end;
  cv := cond^;

  if cv = PTHREAD_COND_INITIALIZER then begin
      Exit(0);
    end;
  result := pthread_mutex_lock (cv.mtxUnblockLock);
  if result <> 0 then
    begin
      Exit(result);
    end;
  if 0 <> cv.nWaitersToUnblock then
  begin
      if 0 = cv.nWaitersBlocked then
      begin
        Exit(pthread_mutex_unlock (cv.mtxUnblockLock));
      end;
      if unblockAll>0 then
      begin
        nSignalsToIssue := cv.nWaitersBlocked;
        cv.nWaitersToUnblock  := cv.nWaitersToUnblock + nSignalsToIssue;
        cv.nWaitersBlocked := 0;
      end
      else
      begin
        nSignalsToIssue := 1;
        Inc(cv.nWaitersToUnblock);
        Dec(cv.nWaitersBlocked);
      end;
  end
  else
  if (cv.nWaitersBlocked > cv.nWaitersGone) then
  begin

    if PTW32_semwait (@cv.semBlockLock ) <> 0 then
    begin
      result := PTW32_GET_ERRNO();
      pthread_mutex_unlock (cv.mtxUnblockLock);
      Exit(result);
    end;
    if 0 <> cv.nWaitersGone then
    begin
      cv.nWaitersBlocked  := cv.nWaitersBlocked - cv.nWaitersGone;
      cv.nWaitersGone := 0;
    end;
    if unblockAll>0 then
    begin
      nSignalsToIssue := cv.nWaitersBlocked;
      cv.nWaitersToUnblock := cv.nWaitersBlocked;
      cv.nWaitersBlocked := 0;
    end
    else
    begin
      nSignalsToIssue := 1;
      cv.nWaitersToUnblock := 1;
      Dec(cv.nWaitersBlocked);
    end;
  end
  else
    begin
      Exit(pthread_mutex_unlock (cv.mtxUnblockLock));
    end;
  result := pthread_mutex_unlock (cv.mtxUnblockLock);
  if Result = 0 then
  begin
    if sem_post_multiple (@cv.semBlockQueue, nSignalsToIssue) <> 0 then
    begin
      result := PTW32_GET_ERRNO();
    end;
  end;
  Exit(result);
end;


function pthread_cond_signal( cond : Ppthread_cond_t):integer;
begin

  Exit((PTW32_cond_unblock (cond, 0)));
end;


function pthread_cond_broadcast( cond : Ppthread_cond_t):integer;
begin

  Exit(PTW32_cond_unblock (cond,  Int(PTW32_TRUE)));
end;

procedure PTW32_cond_wait_cleanup(args: Pointer);
var
  cleanup_args    : Pptw32_cond_wait_cleanup_args_t;
  cv              : pthread_cond_t;
  resultPtr       : Pinteger;
  nSignalsWasLeft,
  result          : integer;
begin
  cleanup_args :=  Pptw32_cond_wait_cleanup_args_t( args);
  cv := cleanup_args.cv;
  resultPtr := cleanup_args.resultPtr;
  result := pthread_mutex_lock (cv.mtxUnblockLock );
  if result <> 0 then
  begin
    resultPtr^ := result;
    exit;
  end;
  nSignalsWasLeft := cv.nWaitersToUnblock;
  if 0 <> nSignalsWasLeft then
  begin
    dec(cv.nWaitersToUnblock);
  end
  else
  begin
    inc(cv.nWaitersGone);
    if (INT_MAX div 2 = (cv.nWaitersGone)) then
    begin

      if PTW32_semwait (@cv.semBlockLock ) <> 0 then
      begin
        resultPtr^ :=  PTW32_GET_ERRNO();
        Exit;
      end;
      cv.nWaitersBlocked  := cv.nWaitersBlocked - cv.nWaitersGone;
      if sem_post (@cv.semBlockLock) <> 0  then
      begin
        resultPtr^ :=  PTW32_GET_ERRNO();
        Exit;
      end;
      cv.nWaitersGone := 0;
    end;
  end;
  result := pthread_mutex_unlock (cv.mtxUnblockLock );
  if result  <> 0 then
  begin
    resultPtr^ := result;
    exit;
  end;
  if 1 = nSignalsWasLeft then
  begin
      if sem_post (@cv.semBlockLock) <> 0 then
      begin
        resultPtr^ :=  PTW32_GET_ERRNO();
        exit;
      end;
  end;
  result := pthread_mutex_lock (cleanup_args.mutexPtr^ );
  if result <> 0 then
     resultPtr^ := result;

end;

function PTW32_cond_timedwait(cond : Ppthread_cond_t; mutex : Ppthread_mutex_t; abstime : Ptimespec):integer;
var
  cv           : pthread_cond_t;
  cleanup_args : PTW32_cond_wait_cleanup_args_t;
  L_cleanup    : ptw32_cleanup_t;
begin
  result := 0;
  if (cond = nil)  or  (cond^ = nil) then
      Exit(EINVAL);


  if cond^ = PTHREAD_COND_INITIALIZER then
     result := PTW32_cond_check_need_init (cond);

  if (result <> 0)  and  (result <> EBUSY) then
     Exit(result);

  cv := cond^;

  if sem_wait (@cv.semBlockLock ) <> 0 then
    begin
      Exit(PTW32_GET_ERRNO());
    end;
  inc(cv.nWaitersBlocked);
  if sem_post (@cv.semBlockLock ) <> 0 then
    begin
      Exit(PTW32_GET_ERRNO());
    end;

  cleanup_args.mutexPtr := mutex;
  cleanup_args.cv := cv;
  cleanup_args.resultPtr := @result;

  L_cleanup.routine := PTW32_cond_wait_cleanup;
  L_cleanup.arg := Pointer(@cleanup_args);
  //pthread_cleanup_push(@PTW32_cond_wait_cleanup, Pointer(@cleanup_args));
  ptw32_push_cleanup(@L_cleanup, PTW32_cond_wait_cleanup, Pointer(@cleanup_args));
  result := pthread_mutex_unlock (mutex^);
  if result =  0 then
  begin
    if sem_timedwait (@cv.semBlockQueue, abstime) <> 0 then
       result := PTW32_GET_ERRNO();

  end;

  ptw32_pop_cleanup (1);


end;


function pthread_cond_wait(cond: Ppthread_cond_t; mutex: Ppthread_mutex_t): Integer;
begin

  Exit((PTW32_cond_timedwait (cond, mutex, nil)));
end;


function pthread_cond_timedwait(cond : Ppthread_cond_t; mutex : Ppthread_mutex_t;const abstime : Ptimespec):integer;
begin
  if abstime = nil then begin
      Exit(EINVAL);
    end;
  Exit((PTW32_cond_timedwait (cond, mutex, abstime)));
end;

function PTW32_cond_check_need_init( cond : Ppthread_cond_t):integer;
var

  node : PTW32_mcs_local_node_t;
begin
  result := 0;

  PTW32_mcs_lock_acquire(@g_PTW32_cond_test_init_lock, @node);

  if cond^ = PTHREAD_COND_INITIALIZER then begin
      result := pthread_cond_init (cond, nil);
    end
  else
  if ( cond^ = nil) then
  begin

    result := EINVAL;
  end;
  PTW32_mcs_lock_release(@node);

end;

function pthread_cond_init(cond: Ppthread_cond_t; const attr: Ppthread_condattr_t): Integer;
var

  cv : pthread_cond_t;
  node : PTW32_mcs_local_node_t;
  label  DONE, FAIL0, FAIL1, FAIL2;
begin
  cv := nil;
  if cond = nil then
      Exit(EINVAL);

  if (attr <> nil)  and  (attr^ <> nil)   and
     (attr^.pshared = Int(PTHREAD_PROCESS_SHARED))  then
      result := ENOSYS;

  cv := pthread_cond_t( calloc (1, sizeof (cv^)));
  if cv = nil then
      result := ENOMEM;

  cv.nWaitersBlocked := 0;
  cv.nWaitersToUnblock := 0;
  cv.nWaitersGone := 0;
  if sem_init (@cv.semBlockLock , 0, 1) <> 0   then
  begin
      result := PTW32_GET_ERRNO();
      goto FAIL0;
  end;

  if sem_init (@cv.semBlockQueue , 0, 0) <> 0  then
  begin
      result := PTW32_GET_ERRNO();
      goto FAIL1;
  end;

  result := pthread_mutex_init (cv.mtxUnblockLock , nil);
  if result <> 0 then
  begin
    goto FAIL2;
  end;
  result := 0;

FAIL2:
  sem_destroy (@cv.semBlockQueue);
FAIL1:
  sem_destroy (@cv.semBlockLock);
FAIL0:
  free (cv);
  cv := nil;
DONE:
  if 0 = result then
  begin
      PTW32_mcs_lock_acquire(@g_PTW32_cond_list_lock, @node);
      cv.next := nil;
      cv.prev := g_PTW32_cond_list_tail;
      if g_PTW32_cond_list_tail <> nil then
      begin
         g_PTW32_cond_list_tail.next := cv;
      end;
      g_PTW32_cond_list_tail := cv;
      if g_PTW32_cond_list_head = nil then
      begin
        g_PTW32_cond_list_head := cv;
      end;
      PTW32_mcs_lock_release(@node);
    end;
  cond^ := cv;
  Exit(result);
end;

end.
