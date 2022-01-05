unit pthreads.rwlock;

interface
uses pthreads.win, libc.Types;

function PTW32_rwlock_check_need_init( rwlock : Ppthread_rwlock_t):integer;
procedure PTW32_rwlock_cancelwrwait( arg : Pointer);

function pthread_rwlock_init(rwlock: Ppthread_rwlock_t; const attr: Ppthread_rwlockattr_t): Integer;

function pthread_rwlock_destroy(rwlock: Ppthread_rwlock_t): Integer;

function pthread_rwlock_tryrdlock(rwlock: Ppthread_rwlock_t): Integer;

function pthread_rwlock_trywrlock(rwlock: Ppthread_rwlock_t): Integer;

function pthread_rwlock_rdlock(rwlock: Ppthread_rwlock_t): Integer;

function pthread_rwlock_timedrdlock(rwlock: Ppthread_rwlock_t; const abstime: Ptimespec): Integer;

function pthread_rwlock_wrlock(rwlock: Ppthread_rwlock_t): Integer;

function pthread_rwlock_timedwrlock(rwlock: Ppthread_rwlock_t; const abstime: Ptimespec): Integer;

function pthread_rwlock_unlock(rwlock: Ppthread_rwlock_t): Integer;

function pthread_rwlockattr_init(attr: Ppthread_rwlockattr_t): Integer;

function pthread_rwlockattr_destroy(attr: Ppthread_rwlockattr_t): Integer;

function pthread_rwlockattr_getpshared(const attr: Ppthread_rwlockattr_t; pshared: PInteger): Integer;

function pthread_rwlockattr_setpshared(attr: Ppthread_rwlockattr_t; pshared: Integer): Integer;

implementation
uses pthreads.mutex, pthreads.ptw32, pthreads.cond, pthreads.core;

function pthread_rwlock_tryrdlock( rwlock : Ppthread_rwlock_t):integer;
var

  rwl : pthread_rwlock_t;
begin
  if (rwlock = nil)  or  (rwlock^ = nil) then begin
      Exit(EINVAL);
    end;
  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
  begin
      result := PTW32_rwlock_check_need_init (rwlock);
      if (result <> 0)  and  (result <> EBUSY) then begin
        Exit(result);
      end;
  end;
  rwl := rwlock^;
  if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then begin
      Exit(EINVAL);
    end;
  result := pthread_mutex_trylock (rwl.mtxExclusiveAccess );
  if Result <> 0 then
    begin
      Exit(result);
    end;
  Inc(rwl.nSharedAccessCount);
  if (rwl.nSharedAccessCount = INT_MAX) then
  begin
    result := pthread_mutex_lock (rwl.mtxSharedAccessCompleted);
    if (Result <> 0) then
    begin
      pthread_mutex_unlock (rwl.mtxExclusiveAccess);
      Exit(result);
    end;
    rwl.nSharedAccessCount  := rwl.nSharedAccessCount - rwl.nCompletedSharedAccessCount;
    rwl.nCompletedSharedAccessCount := 0;
    result := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
    if (Result <> 0) then
    begin
      pthread_mutex_unlock (rwl.mtxExclusiveAccess);
      Exit(result);
    end;
  end;
  Result := (pthread_mutex_unlock (rwl.mtxExclusiveAccess));
end;

procedure PTW32_rwlock_cancelwrwait( arg : Pointer);
var
  rwl : pthread_rwlock_t;
begin
  rwl := pthread_rwlock_t( arg);
  rwl.nSharedAccessCount := -rwl.nCompletedSharedAccessCount;
  rwl.nCompletedSharedAccessCount := 0;
  pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
  pthread_mutex_unlock (rwl.mtxExclusiveAccess);
end;


function pthread_rwlock_timedwrlock(rwlock : Ppthread_rwlock_t;const abstime : Ptimespec):integer;
var
  rwl : pthread_rwlock_t;
  L_cleanup: ptw32_cleanup_t;
begin
  if (rwlock = nil)  or  (rwlock^ = nil) then
      Exit(EINVAL);

  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
  begin
      result := PTW32_rwlock_check_need_init (rwlock);
      if (result <> 0)  and  (result <> EBUSY) then
        Exit(result);

  end;
  rwl := rwlock^;
  if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then
      Exit(EINVAL);

  result := pthread_mutex_timedlock (@rwl.mtxExclusiveAccess, abstime);
  if (result <> 0)  then
  begin
    Exit(result);
  end;

  result := pthread_mutex_timedlock (@rwl.mtxSharedAccessCompleted  , abstime);
  if (result <> 0)  then
  begin
    pthread_mutex_unlock (rwl.mtxExclusiveAccess);
    Exit(result);
  end;
  if rwl.nExclusiveAccessCount = 0 then
  begin
      if rwl.nCompletedSharedAccessCount > 0 then
      begin
        rwl.nSharedAccessCount  := rwl.nSharedAccessCount - rwl.nCompletedSharedAccessCount;
        rwl.nCompletedSharedAccessCount := 0;
      end;
      if rwl.nSharedAccessCount > 0 then
      begin
         rwl.nCompletedSharedAccessCount := -rwl.nSharedAccessCount;
        L_cleanup.routine := PTW32_rwlock_cancelwrwait;
        L_cleanup.arg := Pointer(rwl);
        ptw32_push_cleanup(@L_cleanup, PTW32_rwlock_cancelwrwait, Pointer(@rwl));
        //pthread_cleanup_push (Addr(PTW32_rwlock_cancelwrwait), Pointer( rwl));

        repeat
          result := pthread_cond_timedwait (@rwl.cndSharedAccessCompleted,
                                            @rwl.mtxSharedAccessCompleted,
                                            abstime);
        until (result <> 0)  and  (rwl.nCompletedSharedAccessCount >= 0);

        if (result <> 0) then
           pthread_cleanup_pop (1)
        else
           pthread_cleanup_pop (0);

        if result = 0 then
            rwl.nSharedAccessCount := 0;

      end;
  end;
  if result = 0 then
     Inc( rwl.nExclusiveAccessCount);


end;

function PTW32_rwlock_check_need_init( rwlock : Ppthread_rwlock_t):integer;
var

  node : PTW32_mcs_local_node_t;
begin
  result := 0;
  PTW32_mcs_lock_acquire(@g_PTW32_rwlock_test_init_lock, @node);
  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
  begin
      result := pthread_rwlock_init (rwlock, nil);
  end
  else
  if ( rwlock^ = nil) then
  begin
    result := EINVAL;
  end;
  PTW32_mcs_lock_release(@node);
  Result := result;
end;

function pthread_rwlock_timedrdlock(rwlock : Ppthread_rwlock_t;const abstime : Ptimespec):integer;
var

  rwl : pthread_rwlock_t;
begin
  if (rwlock = nil)  or  (rwlock^ = nil) then
  begin
      Exit(EINVAL);
  end;
  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
  begin
      result := PTW32_rwlock_check_need_init (rwlock);
      if (result <> 0)  and  (result <> EBUSY) then
        Exit(result);

  end;
  rwl := rwlock^;
  if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then
      Exit(EINVAL);
  result := pthread_mutex_timedlock (@rwl.mtxExclusiveAccess , abstime);
  if (Result <> 0)  then
    begin
      Exit(result);
    end;
  Inc(rwl.nSharedAccessCount);
  if (rwl.nSharedAccessCount = INT_MAX) then
  begin
    result := pthread_mutex_timedlock (@rwl.mtxSharedAccessCompleted,  abstime);
    if (Result <> 0) then
    begin
      if result = ETIMEDOUT then
        begin
          Inc(rwl.nCompletedSharedAccessCount);
        end;
      pthread_mutex_unlock (rwl.mtxExclusiveAccess);
      Exit(result);
    end;
    rwl.nSharedAccessCount  := rwl.nSharedAccessCount - rwl.nCompletedSharedAccessCount;
    rwl.nCompletedSharedAccessCount := 0;
    result := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
    if ( Result <> 0) then
    begin
      pthread_mutex_unlock (rwl.mtxExclusiveAccess);
      Exit(result);
    end;
  end;
  Result := pthread_mutex_unlock (rwl.mtxExclusiveAccess);
end;

function pthread_rwlock_rdlock( rwlock : Ppthread_rwlock_t):integer;
var

  rwl : pthread_rwlock_t;
begin
  if (rwlock = nil)  or  (rwlock^ = nil) then begin
      Exit(EINVAL);
    end;
  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
  begin
      result := PTW32_rwlock_check_need_init (rwlock);
      if (result <> 0 ) and  (result <> EBUSY) then
      begin
        Exit(result);
      end;
    end;
  rwl := rwlock^;
  if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then begin
      Exit(EINVAL);
    end;
  result := pthread_mutex_lock (rwl.mtxExclusiveAccess );
  if Result <> 0 then
    begin
      Exit(result);
    end;
  Inc(rwl.nSharedAccessCount);
  if rwl.nSharedAccessCount = INT_MAX then
    begin
      result := pthread_mutex_lock (rwl.mtxSharedAccessCompleted);
      if (Result <> 0) then
      begin
        pthread_mutex_unlock (rwl.mtxExclusiveAccess);
        Exit(result);
      end;
      rwl.nSharedAccessCount  := rwl.nSharedAccessCount - rwl.nCompletedSharedAccessCount;
      rwl.nCompletedSharedAccessCount := 0;
      result := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted );
      if ( Result <> 0)   then
      begin
        pthread_mutex_unlock (rwl.mtxExclusiveAccess);
        Exit(result);
      end;
    end;
  Result := pthread_mutex_unlock (rwl.mtxExclusiveAccess);
end;

function pthread_rwlock_trywrlock( rwlock : Ppthread_rwlock_t):integer;
var
  result0, result1 : integer;
  rwl : pthread_rwlock_t;
begin
  if (rwlock = nil)  or  (rwlock^ = nil) then begin
      Exit(EINVAL);
    end;

  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
  begin
      result0 := PTW32_rwlock_check_need_init (rwlock);
      if (result0 <> 0)  and  (result0 <> EBUSY) then begin
        Exit(result);
      end;
  end;
  rwl := rwlock^;
  if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then
  begin
      Exit(EINVAL);
  end;

  result0 := pthread_mutex_trylock (rwl.mtxExclusiveAccess);
  if  result0 <> 0 then
  begin
    Exit(result0);
  end;
  result0 := pthread_mutex_trylock (rwl.mtxSharedAccessCompleted);
  if (result0 <> 0) then
  begin
    result1 := pthread_mutex_unlock (rwl.mtxExclusiveAccess);
    Exit(get_result( result1, result0));
  end;
  if rwl.nExclusiveAccessCount = 0 then
  begin
      if rwl.nCompletedSharedAccessCount > 0 then
      begin
        rwl.nSharedAccessCount  := rwl.nSharedAccessCount - rwl.nCompletedSharedAccessCount;
        rwl.nCompletedSharedAccessCount := 0;
      end;
      if rwl.nSharedAccessCount > 0 then
      begin
         result0 := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
         if (result0 <> 0) then
          begin
            pthread_mutex_unlock (rwl.mtxExclusiveAccess);
            Exit(result0);
          end;
          result0 := pthread_mutex_unlock (rwl.mtxExclusiveAccess);
         if (result0  = 0) then
             result0 := EBUSY;

      end
      else
      begin
        rwl.nExclusiveAccessCount := 1;
      end;
  end
  else
    result0 := EBUSY;

  Result := result0;
end;

function pthread_rwlock_unlock( rwlock : Ppthread_rwlock_t):integer;
var
  result0, result1 : integer;
  rwl : pthread_rwlock_t;
begin
  if (rwlock = nil)  or  (rwlock = nil) then begin
      Exit((EINVAL));
    end;
  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then begin

      Exit(0);
    end;
  rwl := rwlock^;
  if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then begin
      Exit(EINVAL);
    end;
  if rwl.nExclusiveAccessCount = 0 then
  begin
      result0 := pthread_mutex_lock (rwl.mtxSharedAccessCompleted);
      if (result0 <> 0) then
      begin
        Exit(result0);
      end;
      Inc(rwl.nCompletedSharedAccessCount);
      if (rwl.nCompletedSharedAccessCount = 0)  then
      begin
        result0 := pthread_cond_signal (@(rwl.cndSharedAccessCompleted));
      end;
      result1 := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
  end
  else
  begin
    Dec(rwl.nExclusiveAccessCount);
    result0 := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
    result1 := pthread_mutex_unlock (rwl.mtxExclusiveAccess);
  end;
  Result := get_result(result0, result1);
end;

function pthread_rwlock_wrlock( rwlock : Ppthread_rwlock_t):integer;
var
  rwl : pthread_rwlock_t;
  L_cleanup: ptw32_cleanup_t;
begin
  if (rwlock = nil)  or  (rwlock^ = nil) then begin
      Exit(EINVAL);
    end;

  if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
  begin
      result := PTW32_rwlock_check_need_init (rwlock);
      if (result <> 0)  and  (result <> EBUSY) then begin
        Exit(result);
      end;
  end;
  rwl := rwlock^;
  if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then
      Exit(EINVAL);

  result := pthread_mutex_lock (rwl.mtxExclusiveAccess );
  if result <> 0 then
    begin
      Exit(result);
    end;
  result := pthread_mutex_lock (rwl.mtxSharedAccessCompleted);
  if result <> 0 then
  begin
    pthread_mutex_unlock (rwl.mtxExclusiveAccess);
    Exit(result);
  end;
  if rwl.nExclusiveAccessCount = 0 then
  begin
      if rwl.nCompletedSharedAccessCount > 0 then
      begin
        rwl.nSharedAccessCount  := rwl.nSharedAccessCount - rwl.nCompletedSharedAccessCount;
        rwl.nCompletedSharedAccessCount := 0;
      end;
      if rwl.nSharedAccessCount > 0 then
      begin
        rwl.nCompletedSharedAccessCount := -rwl.nSharedAccessCount;

        L_cleanup.routine := PTW32_rwlock_cancelwrwait;
        L_cleanup.arg := Pointer(rwl);
        ptw32_push_cleanup(@L_cleanup, PTW32_rwlock_cancelwrwait, Pointer(@rwl));
        //pthread_cleanup_push (@PTW32_rwlock_cancelwrwait, Pointer( rwl));
        repeat

            result := pthread_cond_wait (@(rwl.cndSharedAccessCompleted),
                @(rwl.mtxSharedAccessCompleted));

        until (result <> 0)  and  (rwl.nCompletedSharedAccessCount >= 0 );
        if (result <> 0)  then
           pthread_cleanup_pop ( 1)
        else
           pthread_cleanup_pop ( 0);

        if result = 0 then
            rwl.nSharedAccessCount := 0;

      end;
  end;
  if result = 0 then
     Inc( rwl.nExclusiveAccessCount);
end;

function pthread_rwlockattr_destroy( attr : Ppthread_rwlockattr_t):integer;
var

  rwa : pthread_rwlockattr_t;
begin
  result := 0;
  if (attr = nil)  or  (attr^ = nil) then
      result := EINVAL

  else
  begin
    rwa := attr^;
    attr^ := nil;
    free (rwa);
  end;

end;

function pthread_rwlockattr_getpshared(const attr : Ppthread_rwlockattr_t;pshared : Pinteger):integer;
begin
  if (attr <> nil)  and  (attr^ <> nil) and  (pshared <> nil) then
  begin
    pshared^ := attr^.pshared;
    result := 0;
  end
  else
  begin
    result := EINVAL;
  end;

end;

function pthread_rwlockattr_init( attr : Ppthread_rwlockattr_t):integer;
var

  rwa : pthread_rwlockattr_t;
begin
  result := 0;
  rwa := pthread_rwlockattr_t( calloc (1, sizeof ( rwa^)));
  if rwa = nil then
      result := ENOMEM

  else
  begin
    rwa.pshared := Int(PTHREAD_PROCESS_PRIVATE);
  end;
  attr^ := rwa;

end;

function pthread_rwlockattr_setpshared( attr : Ppthread_rwlockattr_t; pshared : integer):integer;
begin
  if (attr <> nil)  and  (attr^ <> nil)   and
      ((pshared = Int(PTHREAD_PROCESS_SHARED))  or
       (pshared = Int(PTHREAD_PROCESS_PRIVATE))) then
  begin
    if pshared = Int(PTHREAD_PROCESS_SHARED) then
    begin
  {$IF not defined( _POSIX_THREAD_PROCESS_SHARED )}
      result := ENOSYS;
      pshared := Int(PTHREAD_PROCESS_PRIVATE);
  {$ELSE}
      result := 0;
{$ENDIF}
    end
    else
    begin
      result := 0;
    end;
    attr^.pshared := pshared;
  end
  else
  begin
    result := EINVAL;
  end;

end;

function pthread_rwlock_init(rwlock : Ppthread_rwlock_t;const attr : Ppthread_rwlockattr_t):integer;
var

  rwl : pthread_rwlock_t;
  label FAIL0, FAIL1, FAIL2, DONE ;
begin
  rwl := nil;
  if rwlock = nil then begin
      Exit(EINVAL);
    end;
  if (attr <> nil)  and  (attr^ <> nil) then begin
      result := EINVAL;
    end;
  rwl := pthread_rwlock_t( calloc (1, sizeof ( rwl^)));
  if rwl = nil then begin
      result := ENOMEM;
    end;
  rwl.nSharedAccessCount := 0;
  rwl.nExclusiveAccessCount := 0;
  rwl.nCompletedSharedAccessCount := 0;
  result := pthread_mutex_init (rwl.mtxExclusiveAccess, nil);
  if result <> 0 then begin
    end;
  result := pthread_mutex_init (rwl.mtxSharedAccessCompleted, nil);
  if result <> 0 then begin
    end;
  result := pthread_cond_init (@rwl.cndSharedAccessCompleted, nil);
  if result <> 0 then begin
    end;
  rwl.nMagic := PTW32_RWLOCK_MAGIC;
  result := 0;
FAIL2:
  pthread_mutex_destroy (rwl.mtxSharedAccessCompleted);
FAIL1:
  pthread_mutex_destroy (rwl.mtxExclusiveAccess);
FAIL0:
  free (rwl);
  rwl := nil;
DONE:
  rwlock^ := rwl;
  Result := result;
end;




function pthread_rwlock_destroy( rwlock : Ppthread_rwlock_t):integer;
var
  rwl : pthread_rwlock_t;
  result0, result1, result2 : integer;
  node : PTW32_mcs_local_node_t;
begin
  result0 := 0; result1 := 0; result2 := 0;
  if (rwlock = nil)  or  (rwlock^ = nil) then begin
      Exit(EINVAL);
    end;
  if rwlock^ <> PTHREAD_RWLOCK_INITIALIZER then
  begin
      rwl := rwlock^;
      if rwl.nMagic <>  PTW32_RWLOCK_MAGIC then
         Exit(EINVAL);
      result0 := pthread_mutex_lock (rwl.mtxExclusiveAccess);
      if result0 <> 0 then
      begin
        Exit(result0);
      end;
      result0 := pthread_mutex_lock (rwl.mtxSharedAccessCompleted);
      if ( result0 <> 0)  then
      begin
        pthread_mutex_unlock (rwl.mtxExclusiveAccess);
        Exit(result0);
      end;

      if (rwl.nExclusiveAccessCount > 0) or
         (rwl.nSharedAccessCount > rwl.nCompletedSharedAccessCount) then
      begin
        result0 := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
        result1 := pthread_mutex_unlock (rwl.mtxExclusiveAccess);
        result2 := EBUSY;
      end
      else
      begin
        rwl.nMagic := 0;
        result0 := pthread_mutex_unlock (rwl.mtxSharedAccessCompleted);
        if ( result0 <> 0)  then
          begin
            pthread_mutex_unlock (rwl.mtxExclusiveAccess);
            Exit(result0);
          end;
        result0 := pthread_mutex_unlock (rwl.mtxExclusiveAccess );
        if (result0 <> 0) then
          begin
            Exit(result0);
          end;
        rwlock^ := nil;
        result := pthread_cond_destroy (@(rwl.cndSharedAccessCompleted));
        result1 := pthread_mutex_destroy (rwl.mtxSharedAccessCompleted);
        result2 := pthread_mutex_destroy (rwl.mtxExclusiveAccess);
        free (rwl);
      end;
  end
  else
  begin

    PTW32_mcs_lock_acquire(@g_PTW32_rwlock_test_init_lock, @node);

    if rwlock^ = PTHREAD_RWLOCK_INITIALIZER then
    begin

      rwlock^ := nil;
    end
    else
    begin

      result0 := EBUSY;
    end;
    PTW32_mcs_lock_release(@node);
  end;
  //((result0 != 0) ? result0 : ((result1 != 0) ? result1 : result2));
  Result := get_result( result0 , get_result( result1 , result2));
end;

end.
