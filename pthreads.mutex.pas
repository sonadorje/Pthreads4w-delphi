unit pthreads.mutex;

interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,
   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

function pthread_mutex_init(var mutex: pthread_mutex_t; const attr: Ppthread_mutexattr_t): Integer;

function pthread_mutex_destroy(var mutex: pthread_mutex_t): Integer;

function pthread_mutex_lock(var mutex: pthread_mutex_t): Integer;

function pthread_mutex_timedlock(mutex: Ppthread_mutex_t; const abstime: Ptimespec): Integer;

function pthread_mutex_trylock(var mutex: pthread_mutex_t): Integer;

function pthread_mutex_unlock(var mutex: pthread_mutex_t): Integer;

function pthread_mutex_consistent(mutex: Ppthread_mutex_t): Integer;
function PTW32_mutex_check_need_init( mutex : Ppthread_mutex_t):integer;

implementation

uses  pthreads.ptw32, pthreads.core;

function PTW32_mutex_check_need_init( mutex : Ppthread_mutex_t):integer;
var

  mtx : pthread_mutex_t;
  node : PTW32_mcs_local_node_t;
begin
   result := 0;
  PTW32_mcs_lock_acquire(@g_PTW32_mutex_test_init_lock, @node);

  mtx := mutex^;
  if mtx = PTHREAD_MUTEX_INITIALIZER then
      result := pthread_mutex_init (mutex^, nil)

  else
  if (mtx = PTHREAD_RECURSIVE_MUTEX_INITIALIZER) then
     result := pthread_mutex_init (mutex^, @g_PTW32_recursive_mutexattr)

  else
  if (mtx = PTHREAD_ERRORCHECK_MUTEX_INITIALIZER) then
     result := pthread_mutex_init (mutex^, @g_PTW32_errorcheck_mutexattr)

  else
  if (mtx = nil) then
     result := EINVAL;

  PTW32_mcs_lock_release(@node);
  Result := (result);
end;

function pthread_mutex_timedlock(mutex : Ppthread_mutex_t;const abstime : Ptimespec):integer;
var
  mx       : pthread_mutex_t;
  kind     : Integer;

  self     : pthread_t;
  statePtr : PTW32_robust_state_t;
begin

  mx := mutex^;
  result := 0;
  if mx = nil then
      Exit(EINVAL);

  if mx >= PTHREAD_ERRORCHECK_MUTEX_INITIALIZER then
  begin
      result := PTW32_mutex_check_need_init (mutex);
      if result  <> 0 then
         Exit((result));

      mx := mutex^;
  end;
  kind := mx.kind;
  if kind >= 0 then
  begin
      if mx.kind = Int(PTHREAD_MUTEX_NORMAL) then
      begin
          if PTW32_INTERLOCKED_LONG(PTW32_INTERLOCKED_EXCHANGE_LONG(
            PInteger( @mx.lock_idx)^,
            PTW32_INTERLOCKED_LONG( 1))) <> 0 then
          begin
              while PTW32_INTERLOCKED_LONG( PTW32_INTERLOCKED_EXCHANGE_LONG(
                               PInteger( &mx.lock_idx)^,
                        PTW32_INTERLOCKED_LONG( -1))) <> 0  do
              begin
                result := PTW32_timed_eventwait (mx.event, abstime);
                if 0 <> Result then
                begin
                  Exit(result);
                end;
              end;
          end;
      end
      else
      begin
          self := pthread_self();
          if PTW32_INTERLOCKED_LONG ( PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG(
                        PTW32_INTERLOCKED_LONGPTR( @mx.lock_idx)^,
            PTW32_INTERLOCKED_LONG( 1),
            PTW32_INTERLOCKED_LONG( 0))) = 0  then
          begin
            mx.recursive_count := 1;
            mx.ownerThread := self;
          end
          else
          begin
            if pthread_equal (mx.ownerThread, self) then
            begin
              if mx.kind = Int(PTHREAD_MUTEX_RECURSIVE) then
                 Inc(mx.recursive_count)
              else
                 Exit(EDEADLK);

            end
            else
            begin
              while PTW32_INTERLOCKED_LONG (   PTW32_INTERLOCKED_EXCHANGE_LONG(
                               PInteger( @mx.lock_idx)^,
                      PTW32_INTERLOCKED_LONG( -1))) <> 0 do
              begin
                result := PTW32_timed_eventwait (mx.event, abstime);
                if 0 <> Result  then
                   Exit(result);

              end;
              mx.recursive_count := 1;
              mx.ownerThread := self;
            end;
          end;
      end;
  end
  else
    begin

      statePtr := &mx.robustNode.stateInconsistent;
      if PTW32_INTERLOCKED_LONG (PTW32_ROBUST_NOTRECOVERABLE )=  PTW32_INTERLOCKED_EXCHANGE_ADD_LONG(
                                                  int(statePtr),
                                                  PTW32_INTERLOCKED_LONG(0)) then
      begin
        result := ENOTRECOVERABLE;
      end
      else
        begin
          self := pthread_self();
          kind := -kind - 1;
          if Int(PTHREAD_MUTEX_NORMAL) = kind then
          begin
              if PTW32_INTERLOCKED_LONG (  PTW32_INTERLOCKED_EXCHANGE_LONG(
                PInteger(@mx.lock_idx)^,
                PTW32_INTERLOCKED_LONG( 1))) <> 0   then
              begin
                 result := PTW32_robust_mutex_inherit(mutex);
                 while (0 = result)  and
                       (PTW32_INTERLOCKED_LONG(  PTW32_INTERLOCKED_EXCHANGE_LONG(
                                                       Pinteger( @mx.lock_idx)^,
                                                      PTW32_INTERLOCKED_LONG( -1)) ) <> 0
                       ) do
                 begin
                      result := PTW32_timed_eventwait (mx.event, abstime);
                      if 0 <> Result then
                      begin
                        Exit(result);
                      end;
                      if PTW32_INTERLOCKED_LONG (PTW32_ROBUST_NOTRECOVERABLE) =
                                   PTW32_INTERLOCKED_EXCHANGE_ADD_LONG(
                                     int(statePtr),
                                     PTW32_INTERLOCKED_LONG(0)) then
                        begin

                          SetEvent(mx.event);
                          result := ENOTRECOVERABLE;
                          break;
                        end;
                    result := PTW32_robust_mutex_inherit(mutex);
                  end;
                  if (0 = result)  or  (EOWNERDEAD = result) then

                      PTW32_robust_mutex_add(mutex, self);

              end;
          end
          else
          begin
              self := pthread_self();
              if 0 =  PTW32_INTERLOCKED_LONG(  PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG(
                            PTW32_INTERLOCKED_LONGPTR( @mx.lock_idx)^,
                PTW32_INTERLOCKED_LONG( 1),
                PTW32_INTERLOCKED_LONG( 0))) then
              begin
                mx.recursive_count := 1;
                PTW32_robust_mutex_add(mutex, self);
              end
              else
              begin
                  if pthread_equal (mx.ownerThread, self ) then
                  begin
                    if Int(PTHREAD_MUTEX_RECURSIVE) = kind then
                    begin
                      Inc(mx.recursive_count);
                    end
                    else
                    begin
                      Exit(EDEADLK);
                    end;
                  end
                  else
                  begin
                      result := PTW32_robust_mutex_inherit(mutex);
                      while (0 = Result)
                                and  (PTW32_INTERLOCKED_LONG(  PTW32_INTERLOCKED_EXCHANGE_LONG(
                                           Pinteger(@mx.lock_idx)^,
                                           PTW32_INTERLOCKED_LONG( -1))) <> 0) do
                      begin
                        result := PTW32_timed_eventwait (mx.event, abstime );
                        if 0 <> Result then

                            Exit(result);

                        result := PTW32_robust_mutex_inherit(mutex);
                      end;
                      if PTW32_INTERLOCKED_LONG ( PTW32_ROBUST_NOTRECOVERABLE )=
                                   PTW32_INTERLOCKED_EXCHANGE_ADD_LONG(
                                     int(statePtr),
                                     PTW32_INTERLOCKED_LONG(0)) then
                        begin

                          SetEvent(mx.event);
                          result := ENOTRECOVERABLE;
                        end
                        else
                        if (0 = result)  or  (EOWNERDEAD = result) then
                        begin
                          mx.recursive_count := 1;

                          PTW32_robust_mutex_add(mutex, self);
                        end;
                  end;
              end;
          end;
        end;
    end;

end;

function pthread_mutex_trylock(var mutex : pthread_mutex_t):integer;
var
  L_mx       : pthread_mutex_t;
  kind, addend     : integer;
  self     : pthread_t;
  statePtr : PTW32_robust_state_t;
begin
  L_mx := mutex;
  result := 0;
  if L_mx = nil then
      Exit(EINVAL);

  if L_mx >= PTHREAD_ERRORCHECK_MUTEX_INITIALIZER then
  begin
      result := PTW32_mutex_check_need_init (@mutex);
      if Result <> 0 then
         Exit(result);

      L_mx := mutex;
  end;

  kind := L_mx.kind;
  if kind >= 0 then
  begin

      if 0 =  PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG (
         {$IFNDEF  WIN64}L_mx.lock_idx{$ELSE} Pint64(@L_mx.lock_idx)^{$ENDIF} , 1,0)then

      begin
        if kind <> Int(PTHREAD_MUTEX_NORMAL) then
        begin
          L_mx.recursive_count := 1;
          L_mx.ownerThread := pthread_self ();
        end;
      end
      else
      begin

        if (kind = Int(PTHREAD_MUTEX_RECURSIVE))  and
           (pthread_equal (L_mx.ownerThread, pthread_self)) then
           Inc(L_mx.recursive_count)

        else
          result := EBUSY;

      end;
  end
  else //kind < 0
  begin
    statePtr := &L_mx.robustNode.stateInconsistent;

    if PTW32_INTERLOCKED_LONG( PTW32_ROBUST_NOTRECOVERABLE) =
                 PTW32_INTERLOCKED_EXCHANGE_ADD_LONG(
                   Int(statePtr), 0) then
      begin
        Exit(ENOTRECOVERABLE);
      end;
    self := pthread_self();
    kind := -kind - 1;
    if 0 =  PTW32_INTERLOCKED_LONG  (PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG (
                  PTW32_INTERLOCKED_LONGPTR( @L_mx.lock_idx)^,
                  PTW32_INTERLOCKED_LONG( 1),
                  PTW32_INTERLOCKED_LONG( 0)))  then
      begin
        if kind <> Int(PTHREAD_MUTEX_NORMAL) then
        begin
          L_mx.recursive_count := 1;
        end;
        PTW32_robust_mutex_add(@mutex, self);
      end
      else
      begin
        if (Int(PTHREAD_MUTEX_RECURSIVE )= kind ) and
           ( pthread_equal (L_mx.ownerThread, pthread_self)) then
        begin
          Inc(L_mx.recursive_count);
        end
        else
        begin
          result := PTW32_robust_mutex_inherit(@mutex);
          if EOWNERDEAD = Result then
          begin
            L_mx.recursive_count := 1;
            PTW32_robust_mutex_add(@mutex, self);
          end
          else
          begin
            if 0 = result then
              result := EBUSY;

          end;
        end;
      end;
  end;

end;

function pthread_mutex_unlock(var mutex : pthread_mutex_t):integer;
var
  mx : pthread_mutex_t;
  kind : integer;
  idx : LONG;
  self : pthread_t;
begin
  mx := mutex;
  result := 0;

  if (mx) < (PTHREAD_ERRORCHECK_MUTEX_INITIALIZER) then
  begin
      kind := mx.kind;
      if kind >= 0 then
      begin
          if kind = Int(PTHREAD_MUTEX_NORMAL) then
          begin
              idx := PTW32_INTERLOCKED_EXCHANGE_LONG(mx.lock_idx, 0);
              if idx <> 0 then
              begin
                  if idx < 0 then
                  begin

                    if SetEvent (mx.event) = LongBool(0) then
                       result := EINVAL;

                  end;
              end;
          end
          else
          begin
            if pthread_equal (mx.ownerThread, pthread_self()) then
              begin

                if (kind <> Int(PTHREAD_MUTEX_RECURSIVE)) or
                   (0 = PreDec(mx.recursive_count)) then
                begin
                  mx.ownerThread.p := nil;
                  if PTW32_INTERLOCKED_EXCHANGE_LONG(mx.lock_idx, 0) < 0 then
                  begin

                    if SetEvent (mx.event) = LongBool(0) then
                       result := EINVAL;

                  end;
                end;
              end
              else
                result := EPERM;

          end;
      end
      else
      begin

        self := pthread_self();
        kind := -kind - 1;

        if pthread_equal (mx.ownerThread, self) then
        begin
           PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG (PTW32_INTERLOCKED_LONGPTR(@mx.robustNode.stateInconsistent)^,
                                                   PTW32_INTERLOCKED_LONG(PTW32_ROBUST_NOTRECOVERABLE),
                                                   PTW32_INTERLOCKED_LONG(PTW32_ROBUST_INCONSISTENT));
          if Int(PTHREAD_MUTEX_NORMAL) = kind then
          begin
              PTW32_robust_mutex_remove(@mutex, nil);
              if LONG ( PTW32_INTERLOCKED_EXCHANGE_LONG (PInteger(@mx.lock_idx)^,
                                                          PTW32_INTERLOCKED_LONG(0))) < 0 then
                begin

                  if SetEvent (mx.event) = LongBool(0) then
                     result := EINVAL;

                end;
          end
          else
          begin

            if (kind <> Int(PTHREAD_MUTEX_RECURSIVE)) or
                (  0 = PreDec(mx.recursive_count))   then
              begin
                PTW32_robust_mutex_remove(@mutex, nil);
                if LONG ( PTW32_INTERLOCKED_EXCHANGE_LONG (PInteger(@mx.lock_idx)^,
                                                             PTW32_INTERLOCKED_LONG( 0))) < 0 then
                begin

                  if SetEvent (mx.event) = LongBool(0) then
                     result := EINVAL;

                end;
              end;
          end;
        end
        else
          result := EPERM;

      end;
  end
  else
  if (mx) <> (PTHREAD_MUTEX_INITIALIZER) then
     result := EINVAL;

end;

function pthread_mutex_consistent( mutex : Ppthread_mutex_t):integer;
var
  mx : pthread_mutex_t;

begin
  mx := mutex^;
  result := 0;

  if mx = nil then begin
      Exit(EINVAL);
    end;
  if (mx.kind >= 0) or
     (PTW32_INTERLOCKED_LONG (PTW32_ROBUST_INCONSISTENT) <>
                 PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG(
                                                 PTW32_INTERLOCKED_LONGPTR(@mx.robustNode.stateInconsistent)^,
                                                 PTW32_INTERLOCKED_LONG(PTW32_ROBUST_CONSISTENT),
                                                 PTW32_INTERLOCKED_LONG(PTW32_ROBUST_INCONSISTENT))) then
    begin
      result := EINVAL;
    end;

end;

function pthread_mutex_lock(var mutex : pthread_mutex_t):integer;
var
  mx       : pthread_mutex_t;
  kind     : Integer;

  self     : pthread_t;
  statePtr : PTW32_robust_state_t;

begin

  mx := mutex;
  result := 0;
  if mx = nil then
     Exit(EINVAL);

  if (mx) >= (PTHREAD_ERRORCHECK_MUTEX_INITIALIZER) then
  begin
      result := PTW32_mutex_check_need_init (@mutex);
      if result =  0 then
          Exit((result));

      mx := mutex;
  end;
  kind := mx.kind;
  if kind >= 0 then
  begin

      if Int(PTHREAD_MUTEX_NORMAL) = kind then
      begin
        if PTW32_INTERLOCKED_EXCHANGE_LONG(mx.lock_idx, 1) <> 0 then
        begin
           while PTW32_INTERLOCKED_EXCHANGE_LONG(
                    mx.lock_idx,-1 ) <> 0 do
            begin
              if WAIT_OBJECT_0 <> WaitForSingleObject (mx.event, INFINITE) then
              begin
                result := EINVAL;
                break;
              end;
            end;
        end;
      end
      else
      begin
          self := pthread_self();
          if PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG(
               {$IFNDEF  WIN64}mx.lock_idx{$ELSE} Pint64(@mx.lock_idx)^{$ENDIF}, 1, 0) = 0  then
          begin
            mx.recursive_count := 1;
            mx.ownerThread := self;
          end
          else
          begin
              if pthread_equal (mx.ownerThread, self) then
              begin
                if kind = Int(PTHREAD_MUTEX_RECURSIVE) then
                   Inc(mx.recursive_count)

                else
                   result := EDEADLK;

              end
              else
              begin
                while PTW32_INTERLOCKED_EXCHANGE_LONG(mx.lock_idx, -1) <> 0  do
                begin
                   if WAIT_OBJECT_0 <> WaitForSingleObject (mx.event, INFINITE )  then
                    begin
                      result := EINVAL;
                      break;
                    end;
                end;
                if 0 = result then
                begin
                  mx.recursive_count := 1;
                  mx.ownerThread := self;
                end;
              end;
          end;
      end;
  end //if kind >= 0
  else
    begin

      statePtr := &mx.robustNode.stateInconsistent;

      if Int(PTW32_ROBUST_NOTRECOVERABLE)  =  PTW32_INTERLOCKED_EXCHANGE_ADD_LONG(
                                                         Integer(statePtr),0 ) then
      begin
        result := ENOTRECOVERABLE;
      end
      else
        begin
          self := pthread_self();
          kind := -kind - 1;
          if Int(PTHREAD_MUTEX_NORMAL) = kind then
          begin
              if PTW32_INTERLOCKED_EXCHANGE_LONG(
                            mx.lock_idx, -1) <> 0 then
              begin
                result := PTW32_robust_mutex_inherit(@mutex);
                while (0 =  result) and
                      ( PTW32_INTERLOCKED_EXCHANGE_LONG(mx.lock_idx, -1) <> 0) do
                begin
                  if WAIT_OBJECT_0 <> WaitForSingleObject (mx.event, INFINITE) then
                  begin
                    result := EINVAL;
                    break;
                  end;
                  if PTW32_INTERLOCKED_LONG(  PTW32_ROBUST_NOTRECOVERABLE) =
                               PTW32_INTERLOCKED_EXCHANGE_ADD_LONG(
                                 int(statePtr),
                                 PTW32_INTERLOCKED_LONG(0))  then
                  begin

                    SetEvent(mx.event);
                    result := ENOTRECOVERABLE;
                    break;
                  end;
                  result := PTW32_robust_mutex_inherit(@mutex);
                end;
              end;
              if (0 = result)  or  (EOWNERDEAD = result) then
                  PTW32_robust_mutex_add(@mutex, self);

          end
          else
          begin
            if PTW32_INTERLOCKED_LONG ( PTW32_INTERLOCKED_COMPARE_EXCHANGE_LONG(
                          PTW32_INTERLOCKED_LONGPTR( @mx.lock_idx)^,
                          PTW32_INTERLOCKED_LONG( 1),
                          PTW32_INTERLOCKED_LONG( 0))) = 0 then
              begin
                mx.recursive_count := 1;

                PTW32_robust_mutex_add(@mutex, self);
              end
              else
              begin
                if pthread_equal (mx.ownerThread, self) then
                begin
                  if Int(PTHREAD_MUTEX_RECURSIVE) = kind then
                     Inc(mx.recursive_count)
                  else
                     result := EDEADLK;

                end
                else
                begin
                  result := PTW32_robust_mutex_inherit(@mutex);
                  while ( 0 = Result)     and
                        (PTW32_INTERLOCKED_LONG(  PTW32_INTERLOCKED_EXCHANGE_LONG(
                                        Pinteger( @mx.lock_idx)^,
                                        PTW32_INTERLOCKED_LONG( -1))) <> 0)  do
                  begin
                    if WAIT_OBJECT_0 <> WaitForSingleObject (mx.event, INFINITE ) then
                    begin
                      result := EINVAL;
                      break;
                    end;
                    if PTW32_INTERLOCKED_LONG  (PTW32_ROBUST_NOTRECOVERABLE) =
                                 PTW32_INTERLOCKED_EXCHANGE_ADD_LONG(
                                   int(statePtr),
                                   PTW32_INTERLOCKED_LONG(0))  then
                      begin

                        SetEvent(mx.event);
                        result := ENOTRECOVERABLE;
                        break;
                      end;
                      result := PTW32_robust_mutex_inherit(@mutex);
                  end;
                  if (0 = result)  or  (EOWNERDEAD = result) then
                  begin
                      mx.recursive_count := 1;

                      PTW32_robust_mutex_add(@mutex, self);
                  end;
                end;
              end;
          end;
        end;
    end;

end;

function pthread_mutex_init(var mutex : pthread_mutex_t;const attr : Ppthread_mutexattr_t):integer;
var

  mx : pthread_mutex_t;
begin
  result := 0;


  if (attr <> nil)  and  (attr^ <> nil) then
  begin
      if attr^.pshared = Int(PTHREAD_PROCESS_SHARED) then
        begin
{$IF _POSIX_THREAD_PROCESS_SHARED >= 0}
          raise Exception.Create(' Process shared mutexes are not supported yet.');
{$ELSE}
          Exit(ENOSYS);
{$ENDIF}
        end;
  end;
  mx := pthread_mutex_t( calloc (1, sizeof ( mx^)));
  if mx = nil then
      result := ENOMEM

  else
  begin
      mx.lock_idx := 0;
      mx.recursive_count := 0;
      mx.robustNode := nil;
      if (attr = nil)  or  (attr^ = nil) then
          mx.kind := Int(PTHREAD_MUTEX_DEFAULT)

      else
      begin
          mx.kind := attr^.kind;
          if attr^.robustness = Int(PTHREAD_MUTEX_ROBUST) then
          begin
            mx.kind := -mx.kind - 1;
            mx.robustNode := Pptw32_robust_node_t( malloc(sizeof(PTW32_robust_node_t)));
            if nil = mx.robustNode then
               result := ENOMEM

            else
            begin
              mx.robustNode.stateInconsistent := PTW32_ROBUST_CONSISTENT;
              mx.robustNode.mx := mx;
              mx.robustNode.next := nil;
              mx.robustNode.prev := nil;
            end;
          end;
      end;
      if 0 = result then
      begin
          mx.ownerThread.p := nil;
          mx.event := CreateEvent (nil,  PTW32_FALSE, PTW32_FALSE, nil);
          if 0 = mx.event then
             result := ENOSPC
          // add by softwind 2012.12.29
          //else  SetEvent(mx.event);
      end;
  end;

  if 0 <> result then
  begin
      if nil <> mx.robustNode then
         free (mx.robustNode);

      free (mx);
      mx := nil;
  end;
  mutex := mx;
  if mutex = nil then
      Exit(EINVAL);
end;

function pthread_mutex_destroy(var mutex : pthread_mutex_t):integer;
var
  mx   : pthread_mutex_t;
  node : PTW32_mcs_local_node_t;
begin

  result := 0;

  if mutex < (PTHREAD_ERRORCHECK_MUTEX_INITIALIZER) then
  begin
      mx := mutex;
      result := pthread_mutex_trylock (mx);

      if (0 = result)  or  (ENOTRECOVERABLE = result) then
      begin
          if (mx.kind <> Int(PTHREAD_MUTEX_RECURSIVE) )  or  (1 = mx.recursive_count) then
          begin

            mutex := nil;
            if (0 = result) then
               result := pthread_mutex_unlock(mx)
            else
               result := 0;
            if 0 = result then
            begin
              if mx.robustNode <> nil then
                 free(mx.robustNode);

              if  not CloseHandle (mx.event ) then
                begin
                  mutex := mx;
                  result := EINVAL;
                end
                else
                  free (mx);

            end
            else
              mutex := mx;

          end
          else
          begin

            Dec(mx.recursive_count);
            result := EBUSY;
          end;
      end;
  end
  else
  begin

    PTW32_mcs_lock_acquire(@g_PTW32_mutex_test_init_lock, @node);

    if mutex >= PTHREAD_ERRORCHECK_MUTEX_INITIALIZER then
       mutex := nil
    else
       result := EBUSY;

    PTW32_mcs_lock_release(@node);
  end;

end;

end.
