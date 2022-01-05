unit pthreads.spin;

interface
uses pthreads.win, libc.Types;

function pthread_spin_init(lock: Ppthread_spinlock_t; pshared: Integer): Integer;

function pthread_spin_destroy(lock: Ppthread_spinlock_t): Integer;

function pthread_spin_lock(lock: Ppthread_spinlock_t): Integer;

function pthread_spin_trylock(lock: Ppthread_spinlock_t): Integer;

function pthread_spin_unlock(lock: Ppthread_spinlock_t): Integer;

implementation
uses pthreads.ptw32, pthreads.mutex, pthreads.mutexattr;

function PTW32_spinlock_check_need_init( lock : Ppthread_spinlock_t):integer;
var

  node : PTW32_mcs_local_node_t;
begin
  result := 0;

  PTW32_mcs_lock_acquire(@g_PTW32_spinlock_test_init_lock, @node);

  if lock^ = PTHREAD_SPINLOCK_INITIALIZER then begin
    result := pthread_spin_init (lock, (PTHREAD_PROCESS_PRIVATE));
  end
  else
  if ( lock^ = nil) then
  begin

    result := EINVAL;
  end;
  PTW32_mcs_lock_release(@node);

end;

function pthread_spin_lock( lock : Ppthread_spinlock_t):integer;
var
  s : pthread_spinlock_t;

begin
  if (nil = lock)  or  (nil = lock^) then begin
      Exit((EINVAL));
    end;
  if lock^ = PTHREAD_SPINLOCK_INITIALIZER then
  begin
      result := PTW32_spinlock_check_need_init (lock);
      if result <> 0 then
      begin
        Exit((result));
      end;
  end;
  s := lock^;
  while PTW32_INTERLOCKED_LONG (PTW32_SPIN_LOCKED) =
    PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG  (PTW32_INTERLOCKED_LONGPTR( @s.interlock)^,
                     PTW32_INTERLOCKED_LONG(  PTW32_SPIN_LOCKED),
                     PTW32_INTERLOCKED_LONG(  PTW32_SPIN_UNLOCKED)) do
    begin
    end;
  if s.interlock =  PTW32_SPIN_LOCKED then begin
    Exit(0);
  end
  else
  if (s.interlock =  PTW32_SPIN_USE_MUTEX) then
    begin
      Exit(pthread_mutex_lock (s.u.mutex));
    end;
  Result := EINVAL;
end;

function pthread_spin_unlock( lock : Ppthread_spinlock_t):integer;
var
  s : pthread_spinlock_t;
begin
  if (nil = lock)  or  (nil = lock^) then begin
      Exit((EINVAL));
    end;
  s := lock^;
  if s = PTHREAD_SPINLOCK_INITIALIZER then begin
      Exit(EPERM);
    end;
  case (
     PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG  (PTW32_INTERLOCKED_LONGPTR( @s.interlock)^,
                 PTW32_INTERLOCKED_LONG(  PTW32_SPIN_UNLOCKED),
                 PTW32_INTERLOCKED_LONG(  PTW32_SPIN_LOCKED))) of

    PTW32_SPIN_LOCKED,
    PTW32_SPIN_UNLOCKED:
      Exit(0);
    PTW32_SPIN_USE_MUTEX:
      Exit(pthread_mutex_unlock (s.u.mutex));
  end;
  Result := EINVAL;
end;

function pthread_spin_trylock( lock : Ppthread_spinlock_t):integer;
var
  s : pthread_spinlock_t;

begin
  if (nil = lock)  or  (nil = lock^) then begin
      Exit((EINVAL));
    end;
  if lock^ = PTHREAD_SPINLOCK_INITIALIZER then
  begin
      result := PTW32_spinlock_check_need_init (lock);
      if result <> 0 then
      begin
        Exit((result));
      end;
  end;
  s := lock^;
  case (
     PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG  (PTW32_INTERLOCKED_LONGPTR(@s.interlock)^,
                      PTW32_INTERLOCKED_LONG(  PTW32_SPIN_LOCKED),
                      PTW32_INTERLOCKED_LONG(  PTW32_SPIN_UNLOCKED))) of

    PTW32_SPIN_UNLOCKED:
      Exit(0);
    PTW32_SPIN_LOCKED:
      Exit(EBUSY);
    PTW32_SPIN_USE_MUTEX:
      Exit(pthread_mutex_trylock (s.u.mutex));
  end;
  Result := EINVAL;
end;

function pthread_spin_destroy( lock : Ppthread_spinlock_t):integer;
var
  s : pthread_spinlock_t;
  node : PTW32_mcs_local_node_t;
begin
  result := 0;
  if (lock = nil)  or  (lock^ = nil) then begin
      Exit(EINVAL);
    end;

  s := lock^;
  if s  <> PTHREAD_SPINLOCK_INITIALIZER then
  begin
      if s.interlock =  PTW32_SPIN_USE_MUTEX then
      begin
        result := pthread_mutex_destroy (s.u.mutex);
      end
      else
      if  PTW32_INTERLOCKED_LONG(  PTW32_SPIN_UNLOCKED) <>
          PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG  (PTW32_INTERLOCKED_LONGPTR( @s.interlock)^,
                PTW32_INTERLOCKED_LONG(  PTW32_SPIN_INVALID),
                PTW32_INTERLOCKED_LONG ( PTW32_SPIN_UNLOCKED)) then
      begin
        result := EINVAL;
      end;
      if 0 = result then
      begin

        lock^ := nil;
        free (s);
      end;
  end
  else
  begin

    PTW32_mcs_lock_acquire(@g_PTW32_spinlock_test_init_lock, @node);

    if lock^ = PTHREAD_SPINLOCK_INITIALIZER then
    begin

      lock^ := nil;
    end
    else
    begin

      result := EBUSY;
    end;
     PTW32_mcs_lock_release(@node);
  end;

end;

function pthread_spin_init( lock : Ppthread_spinlock_t; pshared : integer):integer;
var
  s : pthread_spinlock_t;
  cpus : integer;
  ma : pthread_mutexattr_t;
begin
  cpus := 0;
  result := 0;
  if lock = nil then begin
      Exit(EINVAL);
    end;
  if 0 <> PTW32_getprocessors (@cpus) then
    begin
      cpus := 1;
    end;
  if cpus > 1 then
  begin
      if pshared = Int(PTHREAD_PROCESS_SHARED) then
      begin

      {$IF _POSIX_THREAD_PROCESS_SHARED >= 0}

         raise Exception.Create('Process shared spin locks are not supported yet.');
      {$ELSE}
         Exit(ENOSYS);
      {$ENDIF}
      end;
  end;
  s := pthread_spinlock_t( calloc (1, sizeof ( s^)));
  if s = nil then begin
      Exit(ENOMEM);
    end;
  if cpus > 1 then begin
      s.u.cpus := cpus;
      s.interlock := PTW32_SPIN_UNLOCKED;
  end
  else
  begin
    result := pthread_mutexattr_init (ma);
    if 0 = result then
    begin
      ma.pshared := pshared;
      result := pthread_mutex_init (s.u.mutex, @ma);
      if 0 = result then begin
          s.interlock := PTW32_SPIN_USE_MUTEX;
        end;
    end;
    pthread_mutexattr_destroy (@ma);
  end;
  if 0 = result then
      lock^ := s

  else
  begin
    free (s);
    lock^ := nil;
  end;
  Result := (result);
end;


end.
