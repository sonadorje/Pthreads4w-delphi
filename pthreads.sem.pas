unit pthreads.sem;

interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,

   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

function sem_init(sem: Psem_t; pshared: Integer; value: Cardinal): Integer;
function sem_destroy(sem: Psem_t): Integer;

function sem_trywait(sem: Psem_t): Integer;

function sem_wait(sem: Psem_t): Integer;
function sem_timedwait(sem: Psem_t; const abstime: Ptimespec): Integer;

function sem_post(sem: Psem_t): Integer;

function sem_post_multiple(sem: Psem_t; count: Integer): Integer;

function sem_open(const name : Pchar; oflag : integer): Psem_t; //cdecl; varargs;
function sem_close(sem: Psem_t): Integer;

function sem_unlink(const name: PChar): Integer;

function sem_getvalue(sem: Psem_t; sval: PInteger): Integer;

implementation
uses pthreads.core, pthreads.ptw32;

function sem_wait( sem : Psem_t):integer;
var
  node : PTW32_mcs_local_node_t;
  v : integer;
  s : sem_t;
  L_cleanup: ptw32_cleanup_t;
begin
  result := 0;
  s := sem^;
  pthread_testcancel();
  PTW32_mcs_lock_acquire(@s.lock, @node);
  Dec(s.value);
  v := s.value;
  PTW32_mcs_lock_release(@node);
  if v < 0 then
  begin

      //pthread_cleanup_push(@PTW32_sem_wait_cleanup, Pointer(s));
      L_cleanup.routine := PTW32_sem_wait_cleanup;
      L_cleanup.arg := Pointer(s);
      ptw32_push_cleanup(@L_cleanup, PTW32_sem_wait_cleanup, Pointer(s));
      result := pthreadCancelableWait (s.sem);
      ptw32_pop_cleanup(result);
      //pthread_cleanup_pop(result);

  end;
{$IF defined(NEED_SEM)}
  if  0>= result then
  begin
      PTW32_mcs_lock_acquire(&s.lock, &node);
      if s.leftToUnblock > 0 then begin
          PreDec(s).leftToUnblock;
          SetEvent(s.sem);
        end;
      PTW32_mcs_lock_release(&node);
    end;
{$ENDIF}
  if result <> 0 then begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
    end;
  Exit(0);
end;

function sem_close(sem: Psem_t): Integer;
begin
   PTW32_SET_ERRNO(ENOSYS);
  Result := -1;
end;

function sem_destroy( sem : Psem_t):integer;
var

  s : sem_t;
  node : PTW32_mcs_local_node_t;
begin
  result := 0;
  s := nil;
  if (sem = nil)  or  (sem^ = nil) then begin
      result := EINVAL;
    end
  else
  begin
    s := sem^;
    result := PTW32_mcs_lock_try_acquire(@s.lock, @node);
    if result =  0 then
    begin
        if s.value < 0 then
           result := EBUSY

        else
        begin

          if  not CloseHandle (s.sem ) then
              result := EINVAL;

        end;
        PTW32_mcs_lock_release(@node);
      end;
  end;
  if result <> 0 then begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
    end;
  free (s);
  Exit(0);
end;

function sem_getvalue( sem : Psem_t; sval : Pinteger):integer;
var
  s: sem_t;
  node : PTW32_mcs_local_node_t;
begin
  result := 0;
  s := sem^;
  PTW32_mcs_lock_acquire(@s.lock, @node);
  sval^ := s.value;
  PTW32_mcs_lock_release(@node);
  if result <> 0 then
  begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
  end;
  Result := 0;
end;

function sem_init( sem : Psem_t; pshared : integer; value : uint32):integer;
var

  s : sem_t;
begin
  result := 0;
  s := nil;
  if pshared <> 0 then begin

      result := EPERM;
  end
  else
  if value > UInt32(SEM_VALUE_MAX) then
  begin
    result := EINVAL;
  end
  else
    begin
      s := sem_t( calloc (1, sizeof ( s^)));
      if nil = s then
          result := ENOMEM

      else
      begin
        s.value := value;
        s.lock := nil;
{$IF defined(NEED_SEM)}
        s.sem := CreateEvent (nil,
             PTW32_FALSE,  /
             PTW32_FALSE,  /
            nil);
        if 0 = s.sem then
           result := ENOSPC
        else
           s.leftToUnblock := 0;

{$ELSE }
        s.sem := CreateSemaphore (nil,
                                  long (0),
                                  long( SEM_VALUE_MAX),
                                  nil);
        if (s.sem = 0) then
           result := ENOSPC;

{$ENDIF}
        if result <> 0 then
           free(s);

      end;
    end;
  if result <> 0 then begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
    end;
  sem^ := s;
  Exit(0);
end;

function sem_open(const name : Pchar; oflag : integer):Psem_t; //cdecl;varargs;
begin

   PTW32_SET_ERRNO(ENOSYS);
  Result := SEM_FAILED;
end;

function sem_post( sem : Psem_t):integer;
var

  node : PTW32_mcs_local_node_t;
  s : sem_t;
begin
  result := 0;
  s := sem^;
  PTW32_mcs_lock_acquire(@s.lock, @node);
  if s.value < SEM_VALUE_MAX then
  begin
{$IF defined(NEED_SEM)}
      if PreInc(s then .value <= 0
           and   not SetEvent(s.sem))
        begin
          s.PostDec(value);
          result := EINVAL;
        end;
{$ELSE}
       Inc(s .value);
       if (s.value <= 0)
           and   (not ReleaseSemaphore (s.sem, 1, nil)) then
        begin
          Dec(s.value);
          result := EINVAL;
        end;
{$ENDIF}
  end
  else
  begin
    result := ERANGE;
  end;
  PTW32_mcs_lock_release(@node);
  if result <> 0 then
  begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
  end;
  Result := 0;
end;

function sem_post_multiple( sem : Psem_t; count : integer):integer;
var
  node : PTW32_mcs_local_node_t;
  n: Integer;
  waiters : long;
  s : sem_t;
begin
  result := 0;
  s := sem^;
  PTW32_mcs_lock_acquire(@s.lock, @node);
  if s.value <= (SEM_VALUE_MAX - count ) then
  begin
      waiters := -s.value;
      s.value  := s.value + count;
      if waiters > 0 then
      begin
{$IF defined(NEED_SEM)}
          if SetEvent(s.sem) then
            begin
              PostDec(waiters);
              s.leftToUnblock  := s.leftToUnblock + (count - 1);
              if s.leftToUnblock > waiters then begin
                  s.leftToUnblock := waiters;
                end;
            end;
{$ELSE}
          if waiters<=count then
             n := waiters
          else
             n := count ;

          if ReleaseSemaphore (s.sem,  n, nil) then
          begin

          end
{$ENDIF}
          else
          begin
            s.value  := s.value - count;
            result := EINVAL;
          end;
      end;
  end
  else
  begin
    result := ERANGE;
  end;
  PTW32_mcs_lock_release(@node);
  if result <> 0 then
  begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
  end;
  Result := 0;
end;

function sem_timedwait(sem : Psem_t;const abstime : Ptimespec):integer;
var
  node         : PTW32_mcs_local_node_t;
  milliseconds : DWORD;
  v            : int;

  s            : sem_t;
  timedout     : integer;
  cleanup_args : sem_timedwait_cleanup_args_t;
  L_cleanup    : ptw32_cleanup_t;
  {$IF defined(NEED_SEM)}
      timedout : Int;
  {$ENDIF}
begin
  result := 0;
  s := sem^;
  pthread_testcancel();
  if abstime = nil then begin
      milliseconds := INFINITE;
    end
  else
  begin

    milliseconds := PTW32_relmillisecs (abstime);
  end;
  PTW32_mcs_lock_acquire(@s.lock, @node);
  Dec(s.value);
  v := s.value;
  PTW32_mcs_lock_release(@node);
  if v < 0 then
  begin
{$IF defined(NEED_SEM)}
{$ENDIF}
      cleanup_args.sem := s;
      cleanup_args.resultPtr := @result;

      L_cleanup.routine := PTW32_sem_timedwait_cleanup;
      L_cleanup.arg := Pointer(@cleanup_args);
      ptw32_push_cleanup(@L_cleanup, PTW32_sem_timedwait_cleanup, Pointer(@cleanup_args));
      //pthread_cleanup_push(@PTW32_sem_timedwait_cleanup, Pointer(@cleanup_args));

      result := pthreadCancelableTimedWait (s.sem, milliseconds);
      ptw32_pop_cleanup(result);

{$IF defined(NEED_SEM)}
      if  not timedout then
      begin
          PTW32_mcs_lock_acquire(&s.lock, &node);
          if s.leftToUnblock > 0 then
          begin
              PreDec(s).leftToUnblock;
              SetEvent(s.sem);
            end;
          PTW32_mcs_lock_release(&node);
      end;
{$ENDIF}
end;
  if result <> 0 then begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
    end;
  Exit(0);
end;

function sem_trywait( sem : Psem_t):integer;
var

  s : sem_t;
  node : PTW32_mcs_local_node_t;
begin
  result := 0;
  s := sem^;
  PTW32_mcs_lock_acquire(@s.lock, @node);
  if s.value > 0 then begin
      Dec(s.value);
  end
  else
  begin
    result := EAGAIN;
  end;
  PTW32_mcs_lock_release(@node);
  if result <> 0 then
  begin
       PTW32_SET_ERRNO(result);
      Exit(-1);
  end;
  Exit(0);
end;

function sem_unlink(const name : Pchar):integer;
begin
   PTW32_SET_ERRNO(ENOSYS);
  Result := -1;
end;

end.
