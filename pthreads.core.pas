unit pthreads.core;
{$I config.inc}

interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,
   Winapi.TlHelp32,
   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

function pthread_create(tid: Ppthread_t; const attr: Ppthread_attr_t; start: TStartFunc; arg: Pointer): Integer;

function pthread_detach(thread: pthread_t): Integer;

function pthread_equal(t1: pthread_t; t2: pthread_t):Boolean;

procedure pthread_exit(value_ptr: Pointer);

function pthread_join(thread: pthread_t; value_ptr: PPointer): Integer;

function pthread_self(): pthread_t;

function pthread_cancel(thread: pthread_t): Integer;

function pthread_setcancelstate(state: Integer; oldstate: PInteger): Integer;
function pthread_setcanceltype(&type: Integer; oldtype: PInteger): Integer;

procedure pthread_testcancel();

function pthread_once(once_control: Ppthread_once_t; init_routine: Tpthread_once_init_routine_func): Integer;
function pthread_key_create(var Akey: pthread_key_t; _destructor: Tdestructor_func): Integer;

function pthread_key_delete(key: pthread_key_t): Integer;

function pthread_setspecific(key: pthread_key_t; const value: Pointer): Integer;

function pthread_getspecific(key: pthread_key_t): Pointer;

function pthread_setconcurrency(level: Integer): Integer;

function pthread_getconcurrency(): Integer;

function pthread_kill(thread: pthread_t; sig: Integer): Integer;

function pthread_timedjoin_np(thread: pthread_t; value_ptr: PPointer; const abstime: Ptimespec): Integer;

function pthread_tryjoin_np(thread: pthread_t; value_ptr: PPointer): Integer;
function pthread_setaffinity_np(thread: pthread_t; cpusetsize: NativeUInt; const cpuset: Pcpu_set_t): Integer;

function pthread_getaffinity_np(thread: pthread_t; cpusetsize: NativeUInt; cpuset: Pcpu_set_t): Integer;

function pthread_delay_np(interval: Ptimespec): Integer;

function pthread_num_processors_np(): Integer;

function pthread_getunique_np(thread: pthread_t): UInt64;

procedure pthread_cleanup_pop( _execute: Integer );

function pthread_win32_thread_attach_np(): Boolean;

function pthread_win32_thread_detach_np(): Boolean;

function pthread_win32_getabstime_np(abstime: Ptimespec; const relative: Ptimespec): Ptimespec;

function pthread_win32_test_features_np(feature_mask: Integer): Boolean;

function pthread_timechange_handler_np(arg: Pointer): Pointer;

function pthread_getw32threadhandle_np(thread: pthread_t): THandle;

function pthread_getw32threadid_np(thread: pthread_t): Cardinal;

function pthread_setname_np(thr: pthread_t; const name: PChar): Integer;

function pthread_getname_np(thr: pthread_t; name: PChar; len: Integer): Integer;

function pthreadCancelableWait(waitHandle: THandle): Integer;

function pthreadCancelableTimedWait(waitHandle: THandle; timeout: Cardinal): Integer;
function pthread_win32_process_detach_np(): Boolean;
function pthread_win32_process_attach_np(): integer;

implementation

uses pthreads.ptw32, pthreads.CPU, pthreads.sched,
     pthreads.cond, QueueUser_APCEx;

function GetProcessHandle( szName : LPCTSTR):THANDLE;
var
    hSanpshot : THANDLE;

    pe        : PROCESSENTRY32;
    name      : PChar;
    bOk       : Boolean;
begin
    hSanpshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if INVALID_HANDLE_VALUE = hSanpshot  then begin
        Exit(null);
    end;
    pe.dwSize := sizeof(pe);
    bOk := Process32First (hSanpshot, &pe);
    if  not bOk then
        Exit(null);
    repeat
        name := @pe.szExeFile;
        if  0= lstrcmp (pe.szExeFile, szName ) then
        begin
            Exit(OpenProcess (PROCESS_ALL_ACCESS, FALSE, pe.th32ProcessID));
        end;
        bOk := Process32Next (hSanpshot, &pe);
    until (not bOk);
    Result := null;
end;

function pthread_win32_process_attach_np: Integer;
var
  queue_user_apc_ex_init: Tqueue_user_apc_ex_init_func;
begin
  result := 1;//int(TRUE);
  result := integer(ptw32_processInitialize ());
{$IF defined(_UWIN)}
  PostInc(pthread_count);
{$ENDIF}
{$IF defined(__GNUC__)}
  g_ptw32_features := 0;
{$ELSE }
  g_ptw32_features := Integer(ptw32_SYSTEM_INTERLOCKED_COMPARE_EXCHANGE);
{$ENDIF}



  g_ptw32_register_cancellation := QueueUserAPCEx;

  if not Assigned(g_ptw32_register_cancellation) then
  begin
      g_ptw32_register_cancellation := ptw32_Registercancellation;
      if Null <> ( g_ptw32_h_quserex) then
      begin
        FreeLibrary (g_ptw32_h_quserex);
      end;
      g_ptw32_h_quserex := 0;
  end
  else
  begin
    queue_user_apc_ex_init := QueueUserAPCEx_Init;

    if ( not Assigned(queue_user_apc_ex_init) )  or   (not Assigned(queue_user_apc_ex_init) ) then
    begin
      g_ptw32_register_cancellation := @ptw32_Registercancellation;
      g_ptw32_h_quserex := 0;
    end;
  end;

  g_ptw32_features  := g_ptw32_features  or Int(ptw32_ALERTABLE_ASYNC_CANCEL);


end;


function pthread_win32_process_detach_np:Boolean;
var
  sp: Pptw32_thread_t;
  queue_user_apc_ex_fini: Tqueue_user_apc_ex_fini_func;
begin
  if g_ptw32_processInitialized then
  begin
      sp := Pptw32_thread_t( pthread_getspecific (g_ptw32_selfThreadKey));
      if sp <> nil then
      begin

        if sp.detachState = Int(PTHREAD_CREATE_DETACHED) then
          begin
            PTW32_threadDestroy (sp.ptHandle);
            if Assigned(g_ptw32_selfThreadKey) then
            begin
              TlsSetValue (g_ptw32_selfThreadKey.key, nil);
            end;
          end;
      end;

      PTW32_processTerminate ();
      if g_ptw32_h_quserex > 0 then
      begin


        queue_user_apc_ex_fini :=
        {$IF defined(NEED_UNICODE_CONSTS)}
              GetProcAddress (PTW32_h_quserex,
                  (const TCHAR *) TEXT ('QueueUserAPCEx_Fini'));
        {$ELSE}
              GetProcAddress (g_ptw32_h_quserex, 'QueueUserAPCEx_Fini');
        {$ENDIF}
            if Assigned(queue_user_apc_ex_fini) then
            begin
                queue_user_apc_ex_fini();
            end;
            FreeLibrary (g_ptw32_h_quserex);
      end;
  end;
  Result := TRUE;
end;

procedure pthread_cleanup_pop( _execute: Integer );
begin
   ptw32_pop_cleanup( _execute );
end;

function pthread_num_processors_np:integer;
var
  count : integer;
begin
  if PTW32_getprocessors (@count) <> 0  then
    begin
      count := 1;
    end;
  Result := (count);
end;

function pthread_create(tid : Ppthread_t;const attr : Ppthread_attr_t;start : TStartFunc; arg : Pointer):integer;
var
  thread      : pthread_t;
  tp,
  sp          : Pptw32_thread_t;
  a           : pthread_attr_t;
  threadHandle: THANDLE;
  run         : integer;
  parms       : PThreadParms;
  stackSize   : uint32;
  priority    : integer;
  none,
  attr_cpuset : cpu_set_t;
  stateLock   : PTW32_mcs_local_node_t;

  label FAIL0;

begin
  threadHandle := 0;
  result := EAGAIN;
  run := Int(PTW32_TRUE);
  parms := nil;

  tid.x := 0;
  sp := Pptw32_thread_t (pthread_self().p);
  if nil = sp then
    goto FAIL0;
  if attr <> nil then
    a := attr^
  else
    a := nil;

  thread := PTW32_new();
  if thread.p = nil then
     goto FAIL0;
  tp := Pptw32_thread_t ( thread.p);
  priority := tp.sched_priority;
  parms := PThreadParms (malloc (sizeof ( parms^)));
  if parms = nil then
     goto FAIL0;
  parms.tid := thread;
  parms.start := start;
  parms.arg := arg;

{$IF defined(HAVE_SIGSET_T)}
  tp.sigmask := sp.sigmask;
{$ENDIF}
{$IF defined(HAVE_CPU_AFFINITY)}
  tp.cpuset := sp.cpuset;
{$ENDIF}
  if a <> nil then
  begin
{$IF defined(HAVE_CPU_AFFINITY)}
      _Psched_cpu_set_vector_(@attr_cpuset)._cpuset := a.cpuset;
      CPU_ZERO(@none);
      if  not  CPU_EQUAL(@attr_cpuset, @none) then
      begin
        tp.cpuset := a.cpuset;
      end;
{$ENDIF}
      stackSize := UInt32(a.stacksize);
      tp.detachState := a.detachstate;
      priority := a.param.sched_priority;
      if a.thrname <> nil then
         tp.name := strdup(a.thrname);
{$IF (THREAD_PRIORITY_LOWEST > THREAD_PRIORITY_NORMAL)}

{$ELSE}
    if Int(PTHREAD_INHERIT_SCHED) = a.inheritsched then
       priority := sp.sched_priority;

{$ENDIF}
  end
  else
     stackSize := PTHREAD_STACK_MIN;

  (*
   * State must be >= PThreadStateRunning before we return to the caller.
   * ptw32_threadStart will set state to PThreadStateRunning.
   *)
  if run > 0 then
     tp.state := PThreadStateInitial
  else
    tp.state := PThreadStateSuspended;

  tp.keys := nil;
{$IF defined (__MSVCRT__)  and not  defined (FPC)}

  tp.threadHandle := beginthread ( nil,
                                stackSize,
                                ptw32_threadStart,
                                parms,
                                CREATE_SUSPENDED,
                                tp.thread_id);
  threadHandle := tp.threadHandle;
  if threadHandle <> 0 then
  begin
      if a <> nil then
         PTW32_setthreadpriority (thread, Int(SCHED_OTHER), priority);

{$IF defined(HAVE_CPU_AFFINITY)}
      SetThreadAffinityMask(tp.threadHandle, tp.cpuset);
{$ENDIF}
      if run>0 then
         ResumeThread(threadHandle);

  end;
{$ELSE}
  begin

    PTW32_mcs_lock_acquire(@tp.stateLock, @stateLock);
    threadHandle := THANDLE( beginthread (ptw32_threadStart, parms, tp.thread_id, stackSize));
    tp.threadHandle := threadHandle;
    if threadHandle = THANDLE( - 1) then
    begin
      tp.threadHandle := 0; threadHandle := 0;
    end
    else
    begin
      if  0>= run then begin

          SuspendThread (threadHandle);
        end;
      if a <> nil then
          PTW32_setthreadpriority (thread, Int(SCHED_OTHER), priority);

{$IF defined(HAVE_CPU_AFFINITY)}
      SetThreadAffinityMask(tp.threadHandle, tp.cpuset);
{$ENDIF}
    end;
    PTW32_mcs_lock_release (@stateLock);
  end;
{$ENDIF}

  result := get_result(threadHandle <> 0, 0,  EAGAIN);

FAIL0:
  if result <> 0 then
  begin
      PTW32_threadDestroy (thread);
      tp := nil;
      if parms <> nil then
          free (parms)

  end
  else
      tid^ := thread;

{$IF defined(_UWIN)}
  if result = 0 then PostInc(pthread_count);
{$ENDIF}
end;

procedure pthread_testcancel;
var
  stateLock : PTW32_mcs_local_node_t;
  self      : pthread_t;
  sp        : Pptw32_thread_t;
begin
  self := pthread_self ();
  sp := Pptw32_thread_t ( self.p);
  if sp = nil then
      exit;
  if sp.state <> PThreadStateCancelPending then
      exit;

  PTW32_mcs_lock_acquire (@sp.stateLock, @stateLock);
  if sp.cancelState <> Int(PTHREAD_CANCEL_DISABLE) then
  begin
      ResetEvent(sp.cancelEvent);
      sp.state := PThreadStateCanceling;
      sp.cancelState := Int(PTHREAD_CANCEL_DISABLE);
      PTW32_mcs_lock_release (@stateLock);
      PTW32_throw(PTW32_EPS_CANCEL);

  end;
  PTW32_mcs_lock_release (@stateLock);
end;

function pthread_self():pthread_t;
var
  self,
  _nil         : pthread_t;
  _fail        : bool;
  vThreadMask,
  vProcessMask,
  vSystemMask  : DWORD_PTR;
  sp: Pptw32_thread_t;
  hThread: THANDLE ;
  appname: string;
begin
  _nil.p := nil;
  _nil.x := 0;

  if not ptw32_processInitialize() then
    Exit(_nil);
{$IF defined(_UWIN)}
  if  not Assigned(g_ptw32_selfThreadKey ) then
     Exit(_nil);
{$ENDIF}
  sp := Pptw32_thread_t ( pthread_getspecific (g_ptw32_selfThreadKey));
  if sp <> nil then
  begin
      self := sp.ptHandle;
  end
  else
  begin
    _fail := (PTW32_FALSE);

    self := PTW32_new ();
    sp := Pptw32_thread_t ( self.p);
    if sp <> nil then
    begin

      sp.implicit := 1;
      sp.detachState := Int(PTHREAD_CREATE_DETACHED);
      sp.thread_id := GetCurrentThreadId ();
{$IF defined(NEED_DUPLICATEHANDLE)}

      sp.threadHandle := GetCurrentThread ();
{$ELSE}

      appname := ExtractFileName(paramstr(0));
      if  not DuplicateHandle (GetCurrentProcess ,
                                GetCurrentThread (),
                                GetCurrentProcess, //GetProcessHandle(pchar (appname)),
                                @sp.threadHandle,
                              0, FALSE, DUPLICATE_SAME_ACCESS) then
      begin
        _fail := bool(PTW32_TRUE);
      end;
{$ENDIF}
      if  not _fail then
      begin
{$IF defined(HAVE_CPU_AFFINITY)}

          if GetProcessAffinityMask(GetCurrentProcess(), &vProcessMask, &vSystemMask) then
          begin
            vThreadMask := SetThreadAffinityMask(sp.threadHandle, vProcessMask);
            if vThreadMask>0 then
            begin
                if SetThreadAffinityMask(sp.threadHandle, vThreadMask)>0 then
                   sp.cpuset := size_t( vThreadMask)

                else
                  _fail := (PTW32_TRUE);
            end
            else
              _fail := (PTW32_TRUE);
          end
          else
            _fail := (PTW32_TRUE);
{$ENDIF}
          sp.sched_priority := GetThreadPriority (sp.threadHandle);
          pthread_setspecific (g_ptw32_selfThreadKey, sp);
      end;
    end;

    if _fail then
    begin

      PTW32_threadReusePush (self);

      Exit(_nil);
    end
    else
    begin
       sp.state := PThreadStateRunning;
    end;
  end;
  Result := self;
end;

function pthread_setaffinity_np(thread : pthread_t; cpusetsize : NativeUInt;const cpuset : Pcpu_set_t):integer;
var

  tp            : Pptw32_thread_t;
  node          : PTW32_mcs_local_node_t;
  processCpuset,
  newMask       : cpu_set_t;
begin
{$IF not  defined(HAVE_CPU_AFFINITY)}
  Exit(ENOSYS);
{$ELSE}
  result := 0;
  PTW32_mcs_lock_acquire (@g_ptw32_thread_reuse_lock, @node);
  tp := Pptw32_thread_t ( thread.p);
  if (nil = tp)  or  (thread.x <> tp.ptHandle.x)  or  (Null = tp.threadHandle) then
  begin
    result := ESRCH;
  end
  else
  begin
    if Assigned(cpuset) then
    begin
      if sched_getaffinity(0, sizeof(cpu_set_t), @processCpuset)>0 then
      begin
        result := PTW32_GET_ERRNO();
      end
      else
      begin

        CPU_AND(@newMask, @processCpuset, cpuset);
        if _Psched_cpu_set_vector_( @newMask)._cpuset>0 then
        begin
          if SetThreadAffinityMask (tp.threadHandle, _Psched_cpu_set_vector_(@newMask)._cpuset)>0 then
          begin

            tp.cpuset := _Psched_cpu_set_vector_(@newMask)._cpuset;
          end
          else
          begin
            result := EAGAIN;
          end;
        end
        else
        begin
          result := EINVAL;
        end;
      end;
    end
    else
    begin
      result := EFAULT;
    end;
  end;
  PTW32_mcs_lock_release (@node);
  Exit(result);
{$ENDIF}
end;


function pthread_getaffinity_np( thread : pthread_t; cpusetsize : NativeUInt; cpuset : Pcpu_set_t):integer;
var

  tp          : Pptw32_thread_t;
  node        : PTW32_mcs_local_node_t;
  vThreadMask : DWORD_PTR;
begin
{$IF not  defined(HAVE_CPU_AFFINITY)}
  Exit(ENOSYS);
{$ELSE} result := 0;
  PTW32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
  tp := Pptw32_thread_t ( thread.p);
  if (nil = tp)  or  (thread.x <> tp.ptHandle.x)  or  (Null = tp.threadHandle) then begin
    result := ESRCH;
    end
  else
  begin
    if Assigned(cpuset) then
    begin
      if tp.cpuset>0 then
      begin

          vThreadMask := SetThreadAffinityMask(tp.threadHandle, tp.cpuset);
          if (vThreadMask >0) and  (vThreadMask <> tp.cpuset) then
          begin
             SetThreadAffinityMask(tp.threadHandle, vThreadMask);
            tp.cpuset := vThreadMask;
          end;
      end;
      _Psched_cpu_set_vector_(cpuset)._cpuset := tp.cpuset;
    end
    else
    begin
      result := EFAULT;
    end;
  end;
  PTW32_mcs_lock_release(@node);
  Exit(result);
{$ENDIF}
end;

function pthread_setcancelstate( state : integer; oldstate : pinteger):integer;
var
  stateLock : PTW32_mcs_local_node_t;
  sp        : Pptw32_thread_t;
  self      : pthread_t;
begin
  result := 0;
  self := pthread_self ();
  sp := Pptw32_thread_t ( self.p);
  if (sp = nil)
       or  ( (state <> Int(PTHREAD_CANCEL_ENABLE))  and  (state <> Int(PTHREAD_CANCEL_DISABLE))) then
  begin
    Exit(EINVAL);
  end;

  PTW32_mcs_lock_acquire (@sp.stateLock, @stateLock);
  if oldstate <> nil then begin
    oldstate^ := sp.cancelState;
  end;
  sp.cancelState := state;

  if (state = Int(PTHREAD_CANCEL_ENABLE))
       and  (sp.cancelType = Int(PTHREAD_CANCEL_ASYNCHRONOUS))
       and  (WaitForSingleObject (sp.cancelEvent, 0 ) = WAIT_OBJECT_0 )then
  begin
    sp.state := PThreadStateCanceling;
    sp.cancelState := Int(PTHREAD_CANCEL_DISABLE);
    ResetEvent (sp.cancelEvent);
    PTW32_mcs_lock_release (@stateLock);
    PTW32_throw  (PTW32_EPS_CANCEL);

  end;
  PTW32_mcs_lock_release (@stateLock);

end;

function pthread_setcanceltype( &type : integer; oldtype : Pinteger):integer;
var
  stateLock : PTW32_mcs_local_node_t;

  self      : pthread_t;
  sp        : Pptw32_thread_t;
begin
  result := 0;
  self := pthread_self ();
  sp := Pptw32_thread_t ( self.p);
  if (sp = nil)or
        ( (&type <> Int(PTHREAD_CANCEL_DEFERRED)) and
          (&type <> Int(PTHREAD_CANCEL_ASYNCHRONOUS))) then

      Exit(EINVAL);


  PTW32_mcs_lock_acquire (@sp.stateLock, @stateLock);
  if oldtype <> nil then begin
      oldtype^ := sp.cancelType;
    end;
  sp.cancelType := &type;

  if (sp.cancelState = Int(PTHREAD_CANCEL_ENABLE))   and
      (&type = Int(PTHREAD_CANCEL_ASYNCHRONOUS))  and
      (WaitForSingleObject (sp.cancelEvent, 0)  = WAIT_OBJECT_0)  then
    begin
      sp.state := PThreadStateCanceling;
      sp.cancelState := Int(PTHREAD_CANCEL_DISABLE);
      ResetEvent (sp.cancelEvent);
      PTW32_mcs_lock_release (@stateLock);
      PTW32_throw  (PTW32_EPS_CANCEL);

    end;
  PTW32_mcs_lock_release (@stateLock);

end;

function pthread_setconcurrency( level : integer):integer;
begin
  if level < 0 then begin
      Exit(EINVAL);
  end
  else
  begin
    g_ptw32_concurrency := level;
    Exit(0);
  end;
end;

{$if defined(_MSC_VER)}
const MS_VC_EXCEPTION = $406D1388 ;
procedure SetThreadName( dwThreadID : DWORD; threadName : Pchar);
var
  info : THREADNAME_INFO;
begin
  info.dwType := $1000;
  info.szName := threadName;
  info.dwThreadID := dwThreadID;
  info.dwFlags := 0;
  __try
  begin
    RaiseException( MS_VC_EXCEPTION, 0, sizeof(info)/sizeof(ULONG_PTR), (ULONG_PTR*)&info );
  end;
  __except(EXCEPTION_EXECUTE_HANDLER)
  begin
  end;
end;
{$ENDIF}

{$if defined (PTW32_COMPATIBILITY_BSD) or defined (PTW32_COMPATIBILITY_TRU64)}
function pthread_setname_np(thr : pthread_t;const name : Pchar; arg : Pointer):integer;
var
  threadLock    : PTW32_mcs_local_node_t;
  len,
  result        : integer;
  tmpbuf        : array[0..(PTHREAD_MAX_NAMELEN_NP)-1] of byte;
  newname,
  oldname       : Pchar;
  tp            : Pptw32_thread_t;
  Win32ThreadID : DWORD;
begin
{$IF defined(_MSC_VER)}
{$ENDIF}
  /
  result := pthread_kill (thr, 0);
  if 0 <> result then begin
      Exit(result);
    end;
  /
  len := snprintf(tmpbuf, PTHREAD_MAX_NAMELEN_NP-1, name, arg);
  tmpbuf[PTHREAD_MAX_NAMELEN_NP-1] := #0;
  if len < 0 then begin
      Exit(EINVAL);
    end;
  newname := _strdup(tmpbuf);
{$IF defined(_MSC_VER)}
  Win32ThreadID := pthread_getw32threadid_np (thr);
  if Win32ThreadID then begin
      SetThreadName(Win32ThreadID, newname);
    end;
{$ENDIF}
  tp := (PTW32_thread_t *) thr.p;
  PTW32_mcs_lock_acquire (&tp.threadLock, &threadLock);
  oldname := tp.name;
  tp.name := newname;
  if oldname then begin
      free(oldname);
    end;
  PTW32_mcs_lock_release (&threadLock);
  Result := 0;
end;

{$ELSE}
function pthread_setname_np(thr : pthread_t;const name : Pchar):integer;
var
  threadLock    : PTW32_mcs_local_node_t;
  newname, oldname: PChar;

  tp: Pptw32_thread_t;
  {$IF defined(_MSC_VER)}
  Win32ThreadID : DWORD;
{$ENDIF}
begin

  result := pthread_kill (thr, 0);
  if 0 <> result then begin
      Exit(result);
    end;
  newname := strdup(name);
{$IF defined(_MSC_VER)}
  Win32ThreadID := pthread_getw32threadid_np (thr);
  if Win32ThreadID then begin
      SetThreadName(Win32ThreadID, newname);
    end;
{$ENDIF}
  tp := Pptw32_thread_t ( thr.p);
  PTW32_mcs_lock_acquire (@tp.threadLock, @threadLock);
  oldname := tp.name;
  tp.name := newname;
  if Assigned(oldname) then begin
      free(oldname);
    end;
  PTW32_mcs_lock_release (@threadLock);
  Result := 0;
end;
{$ENDIF}




function pthread_setspecific(key : pthread_key_t;const value : Pointer):integer;
var
  self       : pthread_t;
  sp         : Pptw32_thread_t;
  keyLock,
  threadLock : PTW32_mcs_local_node_t;
  assoc      : PThreadKeyAssoc;
begin
  result := 0;
  if key <> g_ptw32_selfThreadKey then
  begin

      self := pthread_self ();
      if self.p = nil then begin
        Exit(ENOENT);
      end;
  end
  else
  begin

    sp := Pptw32_thread_t ( pthread_getspecific (g_ptw32_selfThreadKey));
    if sp = nil then
    begin
      if value = nil then

          Exit(ENOENT);

        self := Ppthread_t ( value)^;
    end
    else

       self := sp.ptHandle;

  end;

  result := 0;
  if key <> nil then
  begin
      if (self.p <> nil)  and  Assigned(key._destructor)  and  (value <> nil) then
      begin
          sp := Pptw32_thread_t ( self.p);

          PTW32_mcs_lock_acquire(@(key.keyLock), @keyLock);
          PTW32_mcs_lock_acquire(@(sp.threadLock), @threadLock);
          assoc := PThreadKeyAssoc ( sp.keys);

          while assoc <> nil do
          begin
            if assoc.key = key then
                break;

            assoc := assoc.nextKey;
          end;

          if assoc = nil then
              result := PTW32_tkAssocCreate (sp, key);

          PTW32_mcs_lock_release(@threadLock);
          PTW32_mcs_lock_release(@keyLock);
      end;

      if result = 0 then
      begin
        if  not TlsSetValue (key.key, value) then
            result := EAGAIN;

      end;
  end;

end;

function pthread_tryjoin_np( thread : pthread_t; value_ptr : PPointer):integer;
var
  self : pthread_t;
  tp : Pptw32_thread_t;
  node : PTW32_mcs_local_node_t;
begin
  tp := Pptw32_thread_t ( thread.p);
  PTW32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
  if (nil = tp) or  (thread.x <> tp.ptHandle.x) then begin
      result := ESRCH;
  end
  else
  if (Int(PTHREAD_CREATE_DETACHED) = tp.detachState) then
  begin
    result := EINVAL;
  end
  else
  begin
    result := 0;
  end;
  PTW32_mcs_lock_release(@node);
  if result = 0 then
  begin

      self := pthread_self();
      if nil = self.p then begin
        result := ENOENT;
      end
      else
      if (pthread_equal (self, thread)) then
      begin
        result := EDEADLK;
      end
      else
        begin

          result := pthreadCancelableTimedWait (tp.threadHandle, 0);
          if 0 = result then
          begin
              if value_ptr <> nil then
                begin
                  value_ptr^ := tp.exitStatus;
                end;

              result := pthread_detach (thread);
          end
          else
          if (ETIMEDOUT = result) then
          begin
            result := EBUSY;
          end
          else
          begin
            result := ESRCH;
          end;
        end;
    end;
  Exit((result));
end;

function pthread_timedjoin_np(thread : pthread_t; value_ptr : PPointer;const abstime : Ptimespec):integer;
var

  self         : pthread_t;
  milliseconds : DWORD;
  tp           : Pptw32_thread_t;
  node         : PTW32_mcs_local_node_t;
begin
  tp := Pptw32_thread_t ( thread.p);
  if abstime = nil then begin
      milliseconds := INFINITE;
  end
  else
  begin

    milliseconds := PTW32_relmillisecs (abstime);
  end;
  PTW32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
  if (nil = tp) or  (thread.x <> tp.ptHandle.x) then
  begin
      result := ESRCH;
  end
  else
  if (Int(PTHREAD_CREATE_DETACHED) = tp.detachState) then
  begin
    result := EINVAL;
  end
  else
  begin
    result := 0;
  end;
  PTW32_mcs_lock_release(@node);
  if result = 0 then
  begin

      self := pthread_self();
      if nil = self.p then
      begin
          result := ENOENT;
      end
      else
      if (pthread_equal (self, thread)) then
      begin
        result := EDEADLK;
      end
      else
      begin

        result := pthreadCancelableTimedWait (tp.threadHandle, milliseconds);
        if 0 = result then
        begin
            if value_ptr <> nil then
              begin
                value_ptr^ := tp.exitStatus;
              end;

            result := pthread_detach (thread);
        end
        else
        if (ETIMEDOUT <> result) then
        begin
          result := ESRCH;
        end;
      end;
  end;
  Exit((result));
end;

function pthread_timechange_handler_np( arg : Pointer):Pointer;
var
  result1: Integer;
  cv : pthread_cond_t;
  node : PTW32_mcs_local_node_t;
begin
  result1 := 0;
  PTW32_mcs_lock_acquire(@g_ptw32_cond_list_lock, @node);
  cv := g_ptw32_cond_list_head;
  while (cv <> nil)  and  (0 = result1) do
    begin
      result1 := pthread_cond_broadcast (@cv);
      cv := cv.next;
    end;
  PTW32_mcs_lock_release(@node);
  if result1 <> 0  then
     Result1 := EAGAIN
  else
     Result1 := 0;
  Result := Pointer(size_t (Result1));
end;

function pthread_once(once_control : Ppthread_once_t;init_routine : Tpthread_once_init_routine_func):integer;
var
  node : PTW32_mcs_local_node_t;
  L_cleanup: ptw32_cleanup_t;
begin
  if (once_control = nil)  or  ( not Assigned(init_routine) )then begin
      Exit(EINVAL);
    end;
  if (PTW32_INTERLOCKED_LONG ( PTW32_FALSE) =
       PTW32_INTERLOCKED_LONG(PTW32_INTERLOCKED_EXCHANGE_ADD_LONG (PInteger(@once_control.done)^,
                                                                   PTW32_INTERLOCKED_LONG(0))) ) then
    begin
      PTW32_mcs_lock_acquire(Pptw32_mcs_lock_t (@once_control.lock), @node);
      if  0>= once_control.done then
      begin
          L_cleanup.routine := PTW32_mcs_lock_release;
          L_cleanup.arg := Pointer(@node);
          ptw32_push_cleanup(@L_cleanup, PTW32_mcs_lock_release, Pointer(@node));
          //pthread_cleanup_push(@PTW32_mcs_lock_release, @node);
          init_routine();
          ptw32_pop_cleanup(0);

          once_control.done := Int(PTW32_TRUE);
      end;
      PTW32_mcs_lock_release(@node);
    end;
  Exit(0);
end;

function pthread_cancel( thread : pthread_t):integer;
var

  cancel_self : bool;
  self        : pthread_t;
  stateLock   : PTW32_mcs_local_node_t;
  threadHandle     : THANDLE;
  tp:  Pptw32_thread_t;
begin

  result := pthread_kill (thread, 0);
  if 0 <> result then
      Exit(result);

  self := pthread_self() ;
  if self.p = nil then
     Exit(ENOMEM);

  cancel_self := (pthread_equal (thread, self));
  tp := Pptw32_thread_t( thread.p);

  PTW32_mcs_lock_acquire (@tp.stateLock, @stateLock);
  if (tp.cancelType = Int(PTHREAD_CANCEL_ASYNCHRONOUS))  and
     (tp.cancelState = Int(PTHREAD_CANCEL_ENABLE))  and
     (tp.state < PThreadStateCanceling) then
  begin
      if cancel_self then
      begin
        tp.state := PThreadStateCanceling;
        tp.cancelState := Int(PTHREAD_CANCEL_DISABLE);
        PTW32_mcs_lock_release (@stateLock);
        PTW32_throw  (PTW32_EPS_CANCEL);

      end
      else
      begin
          threadHandle := tp.threadHandle;
          SuspendThread (threadHandle);
          if WaitForSingleObject (threadHandle, 0) = WAIT_TIMEOUT then
          begin
            tp.state := PThreadStateCanceling;
            tp.cancelState := Int(PTHREAD_CANCEL_DISABLE);
            if not Assigned(g_ptw32_register_cancellation) then
            begin
               pthread_win32_process_attach_np();
               g_ptw32_register_cancellation(ptw32_cancel_callback, threadHandle, 0);
            end;

            PTW32_mcs_lock_release (@stateLock);
            ResumeThread (threadHandle);
          end;
      end;
  end
  else
  begin

      if tp.state < PThreadStateCancelPending then
      begin
          tp.state := PThreadStateCancelPending;
          if  not SetEvent (tp.cancelEvent) then
              result := ESRCH;

      end
      else
      if (tp.state >= PThreadStateCanceling) then
         result := ESRCH;

      PTW32_mcs_lock_release (@stateLock);
  end;

end;

function pthread_delay_np( interval : Ptimespec):integer;
var
  wait_time,
  secs_in_millisecs,
  millisecs,
  status            : DWORD;
  self              : pthread_t;
  sp                : Pptw32_thread_t;
  stateLock         : PTW32_mcs_local_node_t;
begin
  if interval = nil then
      Exit(EINVAL);

  if (interval.tv_sec = 0)  and  (interval.tv_nsec = 0) then
  begin
      pthread_testcancel ();
      Sleep (0);
      pthread_testcancel ();
      Exit((0));
    end;

  secs_in_millisecs := DWORD(interval.tv_sec * 1000);

  millisecs := (interval.tv_nsec + 999999) div 1000000;
{$IF defined(__WATCOMC__)}
#pragma disable_message (124)
{$ENDIF}
  wait_time := secs_in_millisecs + millisecs;
  if 0 >= ( wait_time )then
    begin
      Exit(EINVAL);
    end;
{$IF defined(__WATCOMC__)}
#pragma enable_message (124)
{$ENDIF}
  self := pthread_self();
  if nil = self.p then
    begin
      Exit(ENOMEM);
    end;
  sp := Pptw32_thread_t ( self.p);
  if sp.cancelState = Int(PTHREAD_CANCEL_ENABLE) then
  begin
      status := WaitForSingleObject (sp.cancelEvent, wait_time);
      if (WAIT_OBJECT_0 = status) then
      begin

        PTW32_mcs_lock_acquire (@sp.stateLock, @stateLock);
        if sp.state < PThreadStateCanceling then
        begin
            sp.state := PThreadStateCanceling;
            sp.cancelState := Int(PTHREAD_CANCEL_DISABLE);
            PTW32_mcs_lock_release (@stateLock);
            PTW32_throw  (PTW32_EPS_CANCEL);
          end;
        PTW32_mcs_lock_release (@stateLock);
        Exit(ESRCH);
      end
      else
      if (status <> WAIT_TIMEOUT) then
      begin
        Exit(EINVAL);
      end;
  end
  else
     Sleep (wait_time);

  Result := (0);
end;



function pthread_detach( thread : pthread_t):integer;
var

  destroyIt : Byte;
  tp        : Pptw32_thread_t;
  reuseLock,
  stateLock : PTW32_mcs_local_node_t;
begin
  destroyIt := Int(PTW32_FALSE);
  tp := Pptw32_thread_t ( thread.p);
  PTW32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @reuseLock);
  if (nil = tp ) or  (thread.x <> tp.ptHandle.x) then
      result := ESRCH

  else
  if int(PTHREAD_CREATE_DETACHED)  = tp.detachState then
     result := EINVAL

  else
  begin

    result := 0;
    PTW32_mcs_lock_acquire (@tp.stateLock, @stateLock);
    if tp.state < PThreadStateLast then
    begin
        tp.detachState := Int(PTHREAD_CREATE_DETACHED);
        if tp.state = PThreadStateExiting then
          destroyIt := Int(PTW32_TRUE);

    end
    else
    if (tp.detachState <> Int(PTHREAD_CREATE_DETACHED)) then
       destroyIt := Int(PTW32_TRUE);

    PTW32_mcs_lock_release (@stateLock);
  end;
  PTW32_mcs_lock_release(@reuseLock);
  if result = 0 then
  begin

      if destroyIt>0 then
      begin

        WaitForSingleObject(tp.threadHandle, INFINITE);
        PTW32_threadDestroy (thread);
      end;
  end;
  Exit((result));
end;

function pthread_equal( t1, t2 : pthread_t):Boolean;
begin
  if ( t1.p = t2.p )  and  (t1.x = t2.x ) then
     result := True
  else
    result := False;
end;

procedure pthread_exit( value_ptr : Pointer);
var
  sp: Pptw32_thread_t;
begin

  sp := Pptw32_thread_t( pthread_getspecific (g_ptw32_selfThreadKey));
{$IF defined(_UWIN)}
  if PreDec(pthread_count then <= 0)
    exit ((int) value_ptr);
{$ENDIF}
  if nil = sp then
  begin

{$IF defined (__MSVCRT__)   and not  defined (FPC)}
    {$if CompilerVersion <= 30}
      endthread (uint32( (size_t(value_ptr))));
    {$ELSE}
      _endthreadex (uint32( (size_t(value_ptr))));
    {$ENDIF}
{$ELSE}
  endthread ();
{$ENDIF}

end;
  sp.exitStatus := value_ptr;
  PTW32_throw  (PTW32_EPS_EXIT);

end;

function pthread_getconcurrency:integer;
begin
  Result := g_ptw32_concurrency;
end;

function pthread_getname_np( thr : pthread_t; name : Pchar; len : integer):integer;
var
  threadLock : PTW32_mcs_local_node_t;
  tp         : Pptw32_thread_t;
  s,
  d          : Pchar;

begin

  result := pthread_kill (thr, 0);
  if 0 <> result then begin
      Exit(result);
    end;
  tp := Pptw32_thread_t ( thr.p);
  PTW32_mcs_lock_acquire (@tp.threadLock, @threadLock);
  s := tp.name; d := name;
  while ( s^ <> #0)  and  (d < &name[len - 1]) do
  begin
    d^ := s^;
    Inc(d);
    Inc(s);
  end;
  d^ := #0;
  PTW32_mcs_lock_release (@threadLock);
  Result := result;
end;



function pthread_getspecific( key : pthread_key_t):Pointer;
var
  lasterror,
  lastWSAerror : integer;
begin
  if key = nil then
     Result := nil

  else
  begin
    lasterror := GetLastError ();
{$IF defined(RETAIN_WSALASTERROR)}
    lastWSAerror := WSAGetLastError ();
{$ENDIF}
    Result  := TlsGetValue (key.key);
    SetLastError (lasterror);
{$IF defined(RETAIN_WSALASTERROR)}
    WSASetLastError (lastWSAerror);
{$ENDIF}
  end;

end;

function pthread_getunique_np( thread : pthread_t):uint64;
begin
  Result := Pptw32_thread_t(thread.p).seqNumber;
end;

function pthread_getw32threadhandle_np( thread : pthread_t): THANDLE;
begin
  Result := Pptw32_thread_t (thread.p).threadHandle;
end;


function pthread_getw32threadid_np( thread : pthread_t):DWORD;
begin
  Result := Pptw32_thread_t (thread.p).thread_id;
end;

function pthread_join( thread : pthread_t; value_ptr : PPointer):integer;
var

  self : pthread_t;
  tp : Pptw32_thread_t;
  node : PTW32_mcs_local_node_t;
begin
  tp := Pptw32_thread_t( thread.p);
  PTW32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
  if (nil = tp) or  (thread.x <> tp.ptHandle.x) then
      result := ESRCH
  else
  if int(PTHREAD_CREATE_DETACHED) = tp.detachState then
     result := EINVAL

  else
     result := 0;

  PTW32_mcs_lock_release(@node);
  if result = 0 then
  begin

      self := pthread_self();
      if nil = self.p then
         result := ENOENT
      else
      if (pthread_equal (self, thread)) then
        result := EDEADLK

      else
      begin
        result := pthreadCancelableWait (tp.threadHandle);
        if 0 = result then
        begin
            if value_ptr <> nil then
               value_ptr^ := tp.exitStatus;

            result := pthread_detach (thread);
        end
        else
           result := ESRCH;

      end;
  end;

end;



function pthreadCancelableWait( waitHandle : THANDLE):integer;
begin
  Result := PTW32_cancelable_wait (waitHandle, INFINITE);
end;


function pthreadCancelableTimedWait( waitHandle : THANDLE; timeout : DWORD):integer;
begin
  Result := (PTW32_cancelable_wait (waitHandle, timeout));
end;

function pthread_key_create(var Akey : pthread_key_t; _destructor : Tdestructor_func):integer;
//var
  //newkey : pthread_key_t;
begin
  result := 0;
  Akey := pthread_key_t( calloc (1, sizeof ( Akey^)));
  if Akey = nil then
  begin
    result := ENOMEM;
  end
  else
  begin
    Akey.key := TlsAlloc();
    if (Akey.key = TLS_OUT_OF_INDEXES) then
    begin
      result := EAGAIN;
      free (Akey);
      Akey := nil;
    end
    else
    if Assigned(_destructor)  then
    begin

      Akey.keyLock := nil;
      Akey._destructor := _destructor;
    end;
  end;


end;


function pthread_key_delete( key : pthread_key_t):integer;
var
  keyLock    : PTW32_mcs_local_node_t;
  assoc      : PThreadKeyAssoc;
  threadLock : PTW32_mcs_local_node_t;
  thread: Pptw32_thread_t;
begin
  result := 0;
  if key <> nil then
  begin
      if (key.threads <> nil)  and  Assigned(key._destructor) then
        begin
          PTW32_mcs_lock_acquire (@key.keyLock, @keyLock);
          assoc := PThreadKeyAssoc(key.threads);
          while (assoc  <> nil) do
          begin
            thread := assoc.thread;
            if assoc = nil then
                break;

            PTW32_mcs_lock_acquire (@thread.threadLock, @threadLock);
            PTW32_tkAssocDestroy (assoc);
            PTW32_mcs_lock_release (@threadLock);
            assoc := PThreadKeyAssoc(key.threads);
          end;
          PTW32_mcs_lock_release (@keyLock);
        end;
      TlsFree (key.key);
      if Assigned(key._destructor ) then
      begin

          PTW32_mcs_lock_acquire (@key.keyLock, @keyLock);
          PTW32_mcs_lock_release (@keyLock);
      end;
{$IF defined( _DEBUG )}
      memset ((char *) key, 0, sizeof ( *key));
{$ENDIF}
      free (key);
  end;

end;

function pthread_kill( thread : pthread_t; sig : integer):integer;
var
  tp: Pptw32_thread_t;
  node : PTW32_mcs_local_node_t;
begin
  result := 0;
  if 0 <> sig then
     result := EINVAL

  else
  begin

    PTW32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
    tp := Pptw32_thread_t ( thread.p);
    if (nil = tp) or  (thread.x <> tp.ptHandle.x) or
       (tp.state < PThreadStateRunning) then
      result := ESRCH;

    PTW32_mcs_lock_release(@node);
  end;

end;

function pthread_win32_getabstime_np(abstime : Ptimespec;const relative : Ptimespec):Ptimespec;
var
  sec,
  nsec        : int64;
  currSysTime : timespec;
  ft          : FILETIME;
  st          : SYSTEMTIME;
begin

{$if defined(WINCE)}
  GetSystemTime(&st);
  SystemTimeToFileTime(&st, &ft);
{$else}
  GetSystemTimeAsFileTime(&ft);
{$ENDIF}
  PTW32_filetime_to_timespec(@ft, @currSysTime);
  sec := currSysTime.tv_sec;
  nsec := currSysTime.tv_nsec;
  if nil <> relative then begin
      nsec  := nsec + relative.tv_nsec;
      if nsec >= NANOSEC_PER_SEC then
      begin
        Inc(sec);
        nsec  := nsec - NANOSEC_PER_SEC;
      end;
      sec  := sec + relative.tv_sec;
    end;
  abstime.tv_sec := time_t( sec);
  abstime.tv_nsec := long( nsec);
  Result := abstime;
end;

function pthread_win32_thread_attach_np:Boolean;
begin
  Result := TRUE;
end;

function pthread_win32_thread_detach_np:Boolean;
var
  stateLock : PTW32_mcs_local_node_t;
  mx        : pthread_mutex_t;
  sp        : Pptw32_thread_t;
begin
  if g_ptw32_processInitialized then
  begin

      sp := Pptw32_thread_t ( pthread_getspecific (g_ptw32_selfThreadKey));
      if sp <> nil then
      begin
          PTW32_callUserDestroyRoutines (sp.ptHandle);
          PTW32_mcs_lock_acquire (@sp.stateLock, @stateLock);
          sp.state := PThreadStateLast;

          PTW32_mcs_lock_release (@stateLock);

          while sp.robustMxList <> nil do
            begin
              mx := sp.robustMxList.mx;
              PTW32_robust_mutex_remove(@mx, sp);
               PTW32_INTERLOCKED_EXCHANGE_LONG(
                        PInteger(@mx.robustNode.stateInconsistent)^,
                        PTW32_INTERLOCKED_LONG(-1));

              SetEvent(mx.event);
            end;
          if sp.detachState = Int(PTHREAD_CREATE_DETACHED) then
          begin
              PTW32_threadDestroy (sp.ptHandle);
              if Assigned(g_ptw32_selfThreadKey) then
                 TlsSetValue (g_ptw32_selfThreadKey.key, nil);

          end;
      end;
  end;
  Result := TRUE;
end;


function pthread_win32_test_features_np( feature_mask : integer):Boolean;
begin
  Result := ((g_ptw32_features and feature_mask) = feature_mask);
end;
end.
