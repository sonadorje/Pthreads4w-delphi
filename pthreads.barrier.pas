unit pthreads.barrier;

interface
uses pthreads.win, libc.Types;

function pthread_barrier_wait(barrier: Ppthread_barrier_t): Integer;
function pthread_barrierattr_init(attr: Ppthread_barrierattr_t): Integer;
function pthread_barrierattr_destroy(attr: Ppthread_barrierattr_t): Integer;
function pthread_barrierattr_getpshared(const attr: Ppthread_barrierattr_t; pshared: PInteger): Integer;
function pthread_barrierattr_setpshared(attr: Ppthread_barrierattr_t; pshared: Integer): Integer;
function pthread_barrier_destroy(barrier: Ppthread_barrier_t): Integer;
function pthread_barrier_init(barrier: Ppthread_barrier_t; const attr: Ppthread_barrierattr_t; count: Cardinal): Integer;

implementation
uses pthreads.sem, pthreads.ptw32;

function pthread_barrier_init( barrier: Ppthread_barrier_t; const attr: Ppthread_barrierattr_t; count: Cardinal): Integer;
var
  b : pthread_barrier_t;
begin
  if (barrier = nil)  or  (count = 0) then
      Exit(EINVAL);

  b := pthread_barrier_t(calloc (1, sizeof (b^)));
  if nil <> b then
  begin
    if (attr <> nil)  and  (attr^ <> nil) then
       b.pshared := attr^.pshared
    else
       b.pshared :=  Int(PTHREAD_PROCESS_PRIVATE);
    b.nCurrentBarrierHeight := count;
    b.nInitialBarrierHeight := count;
    b.lock := nil;
    if 0 = sem_init(@b.semBarrierBreeched  , b.pshared, 0) then
    begin
      barrier^ := b;
      Exit(0);
    end;
    free (b);
  end;
  Result := ENOMEM;
end;

function pthread_barrier_destroy(barrier: Ppthread_barrier_t): Integer;
var
  //result : integer;
  b : pthread_barrier_t;
  node : PTW32_mcs_local_node_t;
begin
  result := 0;
  if (barrier = nil)  or  (barrier^ = pthread_barrier_t(PTW32_OBJECT_INVALID) ) then
  begin
    Exit(EINVAL);
  end;

  if 0 <> PTW32_mcs_lock_try_acquire(@barrier^.lock, @node)  then
  begin
    Exit(EBUSY);
  end;

  b := barrier^;
  if b.nCurrentBarrierHeight < b.nInitialBarrierHeight then
  begin
      result := EBUSY;
  end
  else
  begin
      result := sem_destroy (@b.semBarrierBreeched);
      if 0 = result then
      begin
          barrier^ := pthread_barrier_t(PTW32_OBJECT_INVALID);

          PTW32_mcs_lock_release(@node);
          free (b);
          Exit(0);
      end
      else
      begin

        sem_init (@(b.semBarrierBreeched), b.pshared, 0);
      end;
      if result <> 0 then
      begin
         result := EBUSY;
      end;
  end;
  PTW32_mcs_lock_release(@node);
  Result := (result);
end;

function pthread_barrier_wait( barrier : Ppthread_barrier_t):integer;
var
  //result : integer;
  b : pthread_barrier_t;
  node : PTW32_mcs_local_node_t;
begin
  if (barrier = nil)  or  (barrier^ = pthread_barrier_t( PTW32_OBJECT_INVALID) ) then
      Exit(EINVAL);

  PTW32_mcs_lock_acquire(@barrier^.lock, @node);
  b := barrier^;
  if PreDec(b.nCurrentBarrierHeight) = 0  then
  begin

    PTW32_mcs_node_transfer(@b.proxynode, @node);

    if (b.nInitialBarrierHeight > 1) then
        result :=  sem_post_multiple (@b.semBarrierBreeched, b.nInitialBarrierHeight - 1)
    else
        Result:= 0;
  end
  else
  begin
    PTW32_mcs_lock_release(@node);

    result := PTW32_semwait(@b.semBarrierBreeched);
  end;
  if PTW32_INTERLOCKED_INCREMENT_LONG (
     {$IFNDEF  WIn64}Pinteger(@b.nCurrentBarrierHeight)^ {$ELSE} PInt64(@b.nCurrentBarrierHeight)^ {$ENDIF})
      =  b.nInitialBarrierHeight  then
    begin

      PTW32_mcs_lock_release(@b.proxynode);
      if 0 = result then
          result := Int(PTHREAD_BARRIER_SERIAL_THREAD);

    end;

end;

function pthread_barrierattr_setpshared( attr : Ppthread_barrierattr_t; pshared : integer):integer;
begin
  if (attr <> nil)  and  (attr^ <> nil)  and
      ((pshared = Int(PTHREAD_PROCESS_SHARED))  or
       (pshared = Int(PTHREAD_PROCESS_PRIVATE))) then
  begin
      if pshared = Int(PTHREAD_PROCESS_SHARED) then
      begin
    {$IF not defined( _POSIX_THREAD_PROCESS_SHARED )}
        result := ENOSYS;
        pshared := Int(PTHREAD_PROCESS_PRIVATE);
    {$ELSE} result = 0;
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
  Exit((result));
end;

function pthread_barrierattr_init( attr : Ppthread_barrierattr_t):integer;
var
  ba : pthread_barrierattr_t;
  //result : integer;
begin
  result := 0;
  ba := pthread_barrierattr_t( calloc (1, sizeof ( ba^)));
  if ba = nil then
     result := ENOMEM
  else
     ba.pshared := Int(PTHREAD_PROCESS_PRIVATE);

  attr^ := ba;

end;

function pthread_barrierattr_getpshared(const attr : Ppthread_barrierattr_t; pshared : Pinteger):integer;
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
  Result := (result);
end;

function pthread_barrierattr_destroy( attr : Ppthread_barrierattr_t):integer;
var
  //result : integer;
  ba : pthread_barrierattr_t;
begin
  result := 0;
  if (attr = nil)  or  (attr^ = nil) then
  begin
      result := EINVAL;
  end
  else
  begin
    ba := attr^;
    attr^ := nil;
    free (ba);
  end;
  //Result := (result);
end;

end.
