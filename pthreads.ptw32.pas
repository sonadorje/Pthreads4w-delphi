unit pthreads.ptw32;
{$I config.inc}
interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,

   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

const
   PTW32_SERVICES_FACILITY  =  $BAD;
   PTW32_SERVICES_ERROR     = $DEED;
   SE_SUCCESS              =$00;
   SE_INFORMATION          =$01;
   SE_WARNING              =$02;
   SE_ERROR                =$03;
   EXCEPTION_EXECUTE_HANDLER =      1;
   EXCEPTION_CONTINUE_SEARCH =     0;
   EXCEPTION_CONTINUE_EXECUTION = (-1);


function ptw32_pop_cleanup(execute: Integer): Pptw32_cleanup_t;
function ptw32_get_exception_services_code(): Cardinal;
function ptw32_calloc( n, s : size_t):Pointer;
function ptw32_is_attr(const attr: Ppthread_attr_t): integer;
function ptw32_robust_mutex_inherit( mutex : Ppthread_mutex_t):integer;
function ptw32_get_errno:integer;
function ptw32_semwait( sem : Psem_t):integer;
function ptw32_timed_eventwait(event : THANDLE;const abstime : Ptimespec):integer;
function ptw32_relmillisecs(const abstime : Ptimespec):DWORD;
function ptw32_new:pthread_t;
function ptw32_threadReusePop:pthread_t;
function ptw32_setthreadpriority( thread : pthread_t; policy, priority : integer):integer;
function ptw32_tkAssocCreate( sp : Pptw32_thread_t; key : pthread_key_t):integer;
function ptw32_getprocessors(count : Pinteger):integer;
function ptw32_Registercancellation( unused1 : PAPCFUNC; threadHandle : THANDLE; unused2 : DWORD):DWORD;
function ptw32_mcs_lock_try_acquire( lock : Pptw32_mcs_lock_t; node : Pptw32_mcs_local_node_t):integer;
function ptw32_processInitialize: Boolean;
function ptw32_MAX(a,b: Integer): Integer;inline;
function ptw32_MIN(a,b: Integer): Integer;inline;
function ptw32_cancelable_wait( waitHandle : THANDLE; timeout : DWORD):integer;
function ptw32_threadStart( vthreadParms : Pointer): Integer;

procedure ptw32_mcs_lock_acquire( Alock : Pptw32_mcs_lock_t; node: Pptw32_mcs_local_node_t);
procedure ptw32_push_cleanup(cleanup: Pptw32_cleanup_t; routine: Tcleanup_callback_func; arg: Pointer);
procedure ptw32_mcs_flag_set(flag : PHANDLE);
procedure ptw32_mcs_flag_wait(flag : PHANDLE);
procedure ptw32_mcs_lock_release(Anode : Pointer);//ptw32_mcs_local_node_t);
procedure ptw32_threadDestroy( thread : pthread_t);
procedure ptw32_robust_mutex_add( mutex : Ppthread_mutex_t; self : pthread_t);
procedure ptw32_robust_mutex_remove( mutex : Ppthread_mutex_t; otp : Pptw32_thread_t);
procedure ptw32_threadReusePush( thread : pthread_t);
procedure ptw32_throw( Aexception : DWORD);
procedure ptw32_processTerminate;
procedure ptw32_callUserDestroyRoutines( thread : pthread_t);
procedure ptw32_filetime_to_timespec(const ft : PFILETIME; ts : Ptimespec);
procedure ptw32_set_errno( err : integer);
procedure ptw32_tkAssocDestroy( assoc : PThreadKeyAssoc);
procedure ptw32_pop_cleanup_all( execute : integer);
procedure ptw32_cancel_callback( unused : DWORD);
procedure ptw32_sem_wait_cleanup( sem : Pointer);
procedure ptw32_sem_timedwait_cleanup( args : Pointer);
procedure ptw32_mcs_node_transfer( new_node, old_node : Pptw32_mcs_local_node_t);

const
  EXCEPTION_PTW32_SERVICES = 3954040557;

implementation

uses pthreads.sched, pthreads.core, pthreads.CPU, pthreads.mutex;



procedure longjmp(const jmpb: jmp_buf; retval: integer); register;
asm
{     ->  EAX     jmpb   }
{         EDX     retval }
{     <-  EAX     Result }
          XCHG    EDX, EAX

          MOV     ECX, [EDX+jmp_buf.&EIP]
          // Restore task state
          MOV     EBX, [EDX+jmp_buf.&EBX]
          MOV     ESI, [EDX+jmp_buf.&ESI]
          MOV     EDI, [EDX+jmp_buf.&EDI]
          MOV     ESP, [EDX+jmp_buf.&ESP]
          MOV     EBP, [EDX+jmp_buf.&EBP]
          MOV     [ESP], ECX  // Restore return address (EIP)

          TEST    EAX, EAX    // Ensure retval is <> 0
          JNZ     @@1
          MOV     EAX, 1
@@1:
end;

function  setjmp(out jmpb: jmp_buf): integer; register;
asm
{     ->  EAX     jmpb   }
{     <-  EAX     Result }
          MOV     EDX, [ESP]  // Fetch return address (EIP)
          // Save task state
          MOV     [EAX+jmp_buf.&EBX], EBX
          MOV     [EAX+jmp_buf.&ESI], ESI
          MOV     [EAX+jmp_buf.&EDI], EDI
          MOV     [EAX+jmp_buf.&ESP], ESP
          MOV     [EAX+jmp_buf.&EBP], EBP
          MOV     [EAX+jmp_buf.&EIP], EDX

          SUB     EAX, EAX
@@1:
end;



function ptw32_MAX(a,b: Integer): Integer;
begin
  if a<b then
    exit(b)
  else
    exit(a);
end;

function ptw32_MIN(a,b: Integer): Integer;
begin
  if a>b then
    exit(b)
  else
    exit(a);
end;

function ptw32_calloc( n, s : size_t):Pointer;
var
  p : pointer;
  m: UInt32;
begin
  m := n * s;
  p := malloc (m);
  if p = nil then
     Exit(nil);
  memset (p, 0, m);
  Result := p;
end;

function ptw32_is_attr(const attr: Ppthread_attr_t): integer;
begin

  if (attr = nil)  or
     (attr^ = nil)  or
     ( attr^.valid <>  ptw32_ATTR_VALID) then
     Result := 1
  else
     Result := 0;
end;

function ptw32_get_errno:integer;
var
  err : integer;
begin
  err := 0;
  _get_errno(@err);
  Result := err;
end;

{$if defined(_X86_) and not defined(__amd64__)}
   procedure ptw32_PROGCTR(var Context: TContext; value: DWORD_PTR);
   begin
      {$IFnDEF FPC}
        {$IFNDEF Win64}
         Context.Eip := value;
        {$ELSE}
         Context.Rip := value;
        {$ENDIF}
      {$ELSE}
         Context.Eip := value;
      {$ENDIF}
   end;
{$ENDIF}

 {$if defined (_M_IA64) or defined(_IA64)}
{$define  ptw32_PROGCTR(Context)  ((Context).StIIP)}
{$ENDIF}

{$if defined(_MIPS_) or defined(MIPS)}
{$define  ptw32_PROGCTR(Context)  ((Context).Fir)}
{$ENDIF}

{$if defined(_ALPHA_)}
{$define  ptw32_PROGCTR(Context)  ((Context).Fir)}
{$ENDIF}

{$if defined(_PPC_)}
{$define  ptw32_PROGCTR(Context)  ((Context).Iar)}
{$ENDIF}

{$if defined(_AMD64_) or defined(__amd64__)}
{$define  ptw32_PROGCTR(Context)  ((Context).Rip)}
{$ENDIF}

{$if defined(_ARM_) or defined(ARM) or defined(_M_ARM) or defined(_M_ARM64)}
{$define ptw32_PROGCTR(Context)  ((Context).Pc)}
{$ENDIF}



function ptw32_new: pthread_t;
var
  t, _nil : pthread_t;
  tp : Pptw32_thread_t;

begin
  _nil.p := nil;
  _nil.x := 0;

  //TNullable<pthread_t>.Initialize(_NULL);
  t := ptw32_threadReusePop ();
  if nil <> t.p then begin
      tp := Pptw32_thread_t ( t.p);
  end
  else
  begin

    tp := Pptw32_thread_t ( calloc (1, sizeof(ptw32_thread_t)));
    if tp = nil then
    begin
      Exit(_nil);
    end;

    t.p := tp; tp.ptHandle.p := tp;
    t.x := 0; tp.ptHandle.x := 0;
  end;

  Inc(g_ptw32_threadSeqNumber);
  tp.seqNumber := (g_ptw32_threadSeqNumber);
  tp.sched_priority := THREAD_PRIORITY_NORMAL;
  tp.detachState := Int(PTHREAD_CREATE_JOINABLE);
  tp.cancelState := Int(PTHREAD_CANCEL_ENABLE);
  tp.cancelType := Int(PTHREAD_CANCEL_DEFERRED);
  tp.stateLock := nil;
  tp.threadLock := nil;
  tp.robustMxListLock := nil;
  tp.robustMxList := nil;
  tp.name := nil;
{$IF defined(HAVE_CPU_AFFINITY)}
  CPU_ZERO(Pcpu_set_t(@tp.cpuset));
{$ENDIF}
  tp.cancelEvent := CreateEvent (nil, LongBool(ptw32_TRUE),
                                 LongBool(ptw32_FALSE),
                                 nil);
  //if VarIsNull( tp.cancelEvent) then
  if Null = ( tp.cancelEvent) then
  begin
      ptw32_threadReusePush (tp.ptHandle);
      Exit(_nil);
  end;
  Exit(t);
end;

function ptw32_setthreadpriority( thread : pthread_t; policy, priority : integer):integer;
var
  prio       : integer;
  threadLock : ptw32_mcs_local_node_t;

  tp         : Pptw32_thread_t;
begin
  result := 0;
  tp := Pptw32_thread_t ( thread.p);
  prio := priority;

  if (prio < sched_get_priority_min (policy ))  or
     ( prio > sched_get_priority_max (policy)) then
    begin
      Exit(EINVAL);
    end;
{$IF (THREAD_PRIORITY_LOWEST > THREAD_PRIORITY_NORMAL)}
//
{$ELSE }
  if (THREAD_PRIORITY_IDLE < prio)  and  (THREAD_PRIORITY_LOWEST > prio) then
  begin
      prio := THREAD_PRIORITY_LOWEST;
  end
  else
  if (THREAD_PRIORITY_TIME_CRITICAL > prio)
      and  (THREAD_PRIORITY_HIGHEST < prio) then
  begin
    prio := THREAD_PRIORITY_HIGHEST;
  end;
{$ENDIF}
  ptw32_mcs_lock_acquire (@tp.threadLock, @threadLock);

  if LongBool(0) = SetThreadPriority (tp.threadHandle, prio) then
    begin
      result := EINVAL;
    end
  else
    begin

      tp.sched_priority := priority;
    end;
  ptw32_mcs_lock_release (@threadLock);
  Result := result;
end;

function ptw32_tkAssocCreate( sp : Pptw32_thread_t; key : pthread_key_t):integer;
var
  assoc : PThreadKeyAssoc;
begin

  assoc := PThreadKeyAssoc ( calloc (1, sizeof ( assoc^)));
  if assoc = nil then begin
      Exit(ENOMEM);
    end;
  assoc.thread := sp;
  assoc.key := key;

  assoc.prevThread := nil;
  assoc.nextThread := PThreadKeyAssoc ( key.threads);
  if assoc.nextThread <> nil then begin
      assoc.nextThread.prevThread := assoc;
    end;
  key.threads := Pointer( assoc);

  assoc.prevKey := nil;
  assoc.nextKey := PThreadKeyAssoc ( sp.keys);
  if assoc.nextKey <> nil then begin
      assoc.nextKey.prevKey := assoc;
    end;
  sp.keys := Pointer( assoc);
  Exit((0));
end;

procedure ptw32_processTerminate;
var
  tp, tpNext : Pptw32_thread_t;
  node : ptw32_mcs_local_node_t;
begin
  if g_ptw32_processInitialized then
  begin
      if g_ptw32_selfThreadKey <> nil then
      begin

        pthread_key_delete (g_ptw32_selfThreadKey);
        g_ptw32_selfThreadKey := nil;
      end;
      if g_ptw32_cleanupKey <> nil then
      begin

        pthread_key_delete (g_ptw32_cleanupKey);
        g_ptw32_cleanupKey := nil;
      end;
      ptw32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
      tp := g_ptw32_threadReuseTop;
      while tp <>  ptw32_THREAD_REUSE_EMPTY do
      begin
        tpNext := tp.prevReuse;
        free (tp);
        tp := tpNext;
      end;
      ptw32_mcs_lock_release(@node);
      g_ptw32_processInitialized := ptw32_FALSE;
    end;
end;

function ptw32_processInitialize: Boolean;
begin
  if g_ptw32_processInitialized then begin
      Exit(ptw32_TRUE);
    end;

  g_ptw32_threadReuseTop := ptw32_THREAD_REUSE_EMPTY;
  g_ptw32_threadReuseBottom := ptw32_THREAD_REUSE_EMPTY;
  g_ptw32_selfThreadKey := nil;
  g_ptw32_cleanupKey := nil;
  g_ptw32_cond_list_head := nil;
  g_ptw32_cond_list_tail := nil;
  g_ptw32_concurrency := 0;

  g_ptw32_features := 0;

  g_ptw32_threadSeqNumber := 0;

  g_ptw32_register_cancellation := nil;

  g_ptw32_thread_reuse_lock := nil;

  g_ptw32_mutex_test_init_lock := nil;

  g_ptw32_cond_test_init_lock := nil;

  g_ptw32_rwlock_test_init_lock := nil;

  g_ptw32_spinlock_test_init_lock := nil;

  g_ptw32_cond_list_lock := nil;
  {$IF defined(_UWIN)}

  pthread_count := 0;
  {$ENDIF}
  g_ptw32_processInitialized := ptw32_TRUE;

  if (pthread_key_create (g_ptw32_selfThreadKey, nil) <> 0 )   or
     (pthread_key_create (g_ptw32_cleanupKey, nil) <> 0) then
      ptw32_processTerminate ();

  Exit(g_ptw32_processInitialized);
end;
(*
function wcsncat_s(strDest : Pwchar_t; destMax : size_t;const strSrc : Pwchar_t; count : size_t):errno_t;
begin
    if (destMax = 0)  or  (destMax > SECUREC_WCHAR_STRING_MAX_LEN) then
    begin
        SECUREC_ERROR_INVALID_RANGE('wcsncat_s');
        Exit(ERANGE);
    end;
    if (strDest = nil)  or  (strSrc = nil) then
    begin
        SECUREC_ERROR_INVALID_PARAMTER('wcsncat_s');
        if strDest <> nil then
        begin
            strDest[0] := #0;
            Exit(EINVAL_AND_RESET);
        end;
        Exit(EINVAL);
    end;
    if count > SECUREC_WCHAR_STRING_MAX_LEN then
    begin
{$IFDEF SECUREC_COMPATIBLE_WIN_FORMAT}
        if count = (size_t(-1)) then
        begin

            Exit(SecDoCatLimitW(strDest, destMax, strSrc, destMax));
        end;
{$ENDIF}
        strDest[0] := #0;
        SECUREC_ERROR_INVALID_RANGE('wcsncat_s');
        Exit(ERANGE_AND_RESET);
    end;
    Result := SecDoCatLimitW(strDest, destMax, strSrc, count);
end;
*)
procedure ptw32_callUserDestroyRoutines( thread : pthread_t);
var
  assoc           : PThreadKeyAssoc;
  threadLock,
  keyLock         : ptw32_mcs_local_node_t;
  assocsRemaining,
  iterations      : integer;
  k               : pthread_key_t;
  sp              : Pptw32_thread_t;
  _destructor     : Tdestructor_func;
  value           : Pointer;
  I               : Integer;
begin
  if thread.p <> nil then
  begin
      iterations := 0;
      sp := Pptw32_thread_t ( thread.p);


    repeat
          assocsRemaining := 0;
          Inc(iterations);
          ptw32_mcs_lock_acquire(@(sp.threadLock), @threadLock);

          sp.nextAssoc := sp.keys;
          ptw32_mcs_lock_release(@threadLock);
          for I := 0 to 1000 do

          begin


              ptw32_mcs_lock_acquire(@(sp.threadLock), @threadLock);
              assoc := PThreadKeyAssoc(sp.nextAssoc);
              if assoc = nil then
              begin

                ptw32_mcs_lock_release(@threadLock);
                break;
              end
              else
              begin

                if ptw32_mcs_lock_try_acquire(@assoc.key.keyLock  , @keyLock) = EBUSY then
                  begin
                    ptw32_mcs_lock_release(@threadLock);
                    Sleep(0);

                    continue;
                  end;
              end;

              sp.nextAssoc := assoc.nextKey;

              k := assoc.key;
              _destructor := k._destructor;
              value := TlsGetValue(k.key);
              TlsSetValue (k.key, nil);
              if (value <> nil)  and  (iterations <= PTHREAD_DESTRUCTOR_ITERATIONS) then
              begin

                ptw32_mcs_lock_release(@threadLock);
                ptw32_mcs_lock_release(@keyLock);
                Inc(assocsRemaining);
                {$IF defined(__cplusplus)}
                      try


                          _destructor (value);

                      except on E: exception do

                          terminate ();
                      end;
                {$ELSE }

                   _destructor(value);
                {$ENDIF}
              end
              else
              begin

                ptw32_tkAssocDestroy (assoc);
                ptw32_mcs_lock_release(@threadLock);
                ptw32_mcs_lock_release(@keyLock);
              end;
         end;
    until assocsRemaining <=0;
  end;
end;

function MAKE_SOFTWARE_EXCEPTION( _severity, _facility, _exception : integer):DWORD;
begin
 Result :=  ( ( (_severity)  shl  30 ) or     { Severity code        }

            ( 1  shl  29 ) or               { MS=0, User=1         }

            ( 0  shl  28 ) or               { Reserved             }

            ( (_facility)  shl  16 ) or     { Facility Code        }

            ( (_exception)  shl   0 )      { Exception Code       }

            ) ;
end;


function ExceptionFilter( ep : PExceptionRecord; ei : PULONG_PTR):DWORD;
var
  param,
  numParams : DWORD;
  self      : pthread_t;

begin
{$POINTERMATH ON}

  case ep.ExceptionRecord.ExceptionCode of
      EXCEPTION_PTW32_SERVICES:
      begin
        numParams := ep.ExceptionRecord.NumberParameters;
        numParams := get_result(numParams > 3, 3 , numParams);
        for param := 0 to numParams-1 do
          begin
            ei[param] := DWORD(ep.ExceptionRecord.ExceptionInformation[param]);
          end;
        Exit(EXCEPTION_EXECUTE_HANDLER);
      end
      else
      begin
  {
   * A system unexpected exception has occurred running the user's
   * routine. We need to cleanup before letting the exception
   * out of thread scope.
   }
        self := pthread_self ();
        ptw32_callUserDestroyRoutines (self);
        Exit(EXCEPTION_CONTINUE_SEARCH);
      end;
  end;
    {$POINTERMATH OFF}
end;

function ptw32_threadStart( vthreadParms : Pointer): Integer;
var
  threadParms : PThreadParms;
  self        : pthread_t;
  sp          : Pptw32_thread_t;
  arg         : Pointer;
  {$IF defined(ptw32_CLEANUP_C)}

  setjmp_rc   : integer;
  {$ENDIF}
  stateLock   : ptw32_mcs_local_node_t;
  status      : Pointer;
  start       : TStartFunc;
  {$IF defined(ptw32_CLEANUP_SEH)}

  ei: array[0..2] of ULONG_PTR ;

  {$ENDIF}
begin
  threadParms := PThreadParms ( vthreadParms);
  {$IF defined(ptw32_CLEANUP_SEH)}
  ei[0] := 0; ei[1] := 0;ei[2] := 0;
  {$ENDIF}

  status := Pointer( 0);
  self := threadParms.tid;
  sp := Pptw32_thread_t( self.p);
  start := threadParms.start;
  arg := threadParms.arg;
  free (threadParms);
{$IF   defined (__MSVCRT__)  }
{$ELSE }
  sp.thread := GetCurrentThreadId ();
{$ENDIF}
  pthread_setspecific (g_ptw32_selfThreadKey, sp);

  ptw32_mcs_lock_acquire (@sp.stateLock, @stateLock);
  sp.state := PThreadStateRunning;
  ptw32_mcs_lock_release (@stateLock);
{$IF defined(ptw32_CLEANUP_SEH)}
  try
 
    sp.exitStatus := start (arg);
    status := sp.exitStatus;
    sp.state := PThreadStateExiting;
    {$IF defined(_UWIN)}
    if PreDec(pthread_count then <= 0)
       exit (0);
    {$ENDIF}

  except on E: EExternalException do
    begin


      ExceptionFilter(E.ExceptionRecord, @ei);
      case ei[0] of
          ptw32_EPS_CANCEL:
          begin
            status :=  PTHREAD_CANCELED;
            sp.exitStatus := PTHREAD_CANCELED;
          {$IF defined(_UWIN)}
            if PreDec(pthread_count then <= 0)
            exit (0);
          {$ENDIF}
          end;
          ptw32_EPS_EXIT:
            status := sp.exitStatus;

          else
          begin
            status := PTHREAD_CANCELED;
            sp.exitStatus := PTHREAD_CANCELED
          end;

      end;
    end;
  end;
{$ELSEIF defined(ptw32_CLEANUP_C)}

  setjmp_rc := setjmp (sp.start_mark);
  if 0 = setjmp_rc then
  begin
      sp.exitStatus := start(arg);
      status := sp.exitStatus;
      sp.state := PThreadStateExiting;
  end
  else
  begin
    case setjmp_rc of
        ptw32_EPS_CANCEL:
        begin
           status := PTHREAD_CANCELED;
           sp.exitStatus := PTHREAD_CANCELED;
        end;
        ptw32_EPS_EXIT:
           status := sp.exitStatus;

        else
        begin
           status := PTHREAD_CANCELED;
           sp.exitStatus := PTHREAD_CANCELED;
        end;

    end;
  end;
{$ELSEIF defined(PTW32_CLEANUP_CXX)}

  try
  begin
    status := sp.exitStatus = ( *start) (arg);
    sp.state := PThreadStateExiting;
  end;
  catch (ptw32_exception_cancel &)
  begin
    {
     * Thread was canceled.
     }
    status := sp.exitStatus = PTHREAD_CANCELED;
  end;
  catch (ptw32_exception_exit &)
  begin
    {
     * Thread was exited via pthread_exit().
     }
    status := sp.exitStatus;
  end;
  catch (...)
  begin
    {
     * Some other exception occurred. Clean up while we have
     * the opportunity, and call the terminate handler.
     }
    (void) pthread_win32_thread_detach_np ();
    terminate ();
  end;
{$ENDIF}

{$IF defined (ptw32_STATIC_LIB)}
  (void) pthread_win32_thread_detach_np ();
{$ENDIF}

{$IF  defined (__MSVCRT__)  and not  defined (FPC)}
   endthread (uint32(size_t(status)));
{$ELSE}
  endthread ();
{$ENDIF}

end;

{$if defined(ptw32_USES_SEPARATE_CRT) and (defined(ptw32_CLEANUP_CXX) or defined(ptw32_CLEANUP_SEH))}
function pthread_win32_set_terminate_np( termFunction : ptw32_terminate_handler):ptw32_terminate_handler;
begin
  Result := set_terminate(termFunction);
end;
{$ENDIF}

procedure ptw32_timespec_to_filetime(const ts : Ptimespec; ft : PFILETIME);
begin
   Puint64_t(ft)^ := ts.tv_sec * 10000000
    + (ts.tv_nsec + 50) div 100 +  ptw32_TIMESPEC_TO_FILETIME_OFFSET;
end;


procedure ptw32_filetime_to_timespec(const ft : PFILETIME; ts : Ptimespec);
begin
  ts.tv_sec := int (( Puint64_t(ft)^  -  ptw32_TIMESPEC_TO_FILETIME_OFFSET) div 10000000);
  ts.tv_nsec := int (( Puint64_t(ft)^  -  ptw32_TIMESPEC_TO_FILETIME_OFFSET -
                       uint64_t( ts.tv_sec) * uint64_t( 10000000) * 100));
end;


procedure ptw32_sem_timedwait_cleanup( args : Pointer);
var
  node : ptw32_mcs_local_node_t;
  a : Psem_timedwait_cleanup_args_t;
  s : sem_t;
begin
  a := Psem_timedwait_cleanup_args_t(args);
  s := a.sem;
  ptw32_mcs_lock_acquire(@s.lock, @node);

  if WaitForSingleObject(s.sem, 0 ) = WAIT_OBJECT_0 then
  begin

    a.resultPtr^ := 0;
  end
  else
    begin

      Inc(s.value);
{$IF defined(NEED_SEM)}
      if s.value > 0 then begin
          s.leftToUnblock := 0;
        end;
{$ELSE }
{$ENDIF}
    end;
  ptw32_mcs_lock_release(@node);
end;



procedure ptw32_sem_wait_cleanup( sem : Pointer);
var
  s : sem_t;
  node : ptw32_mcs_local_node_t;
begin
  s := sem_t( sem);
  ptw32_mcs_lock_acquire(@s.lock, @node);

  if (Psem_t(sem)^ <> nil ) and
     (WaitForSingleObject(s.sem, 0) <> WAIT_OBJECT_0) then
    begin
      Inc(s.value);
{$IF defined(NEED_SEM)}
      if s.value > 0 then begin
          s.leftToUnblock := 0;
        end;
{$ELSE }
{$ENDIF }
    end;
  ptw32_mcs_lock_release(@node);
end;

function ptw32_getprocessors(count : Pinteger):integer;
var
  vProcessCPUs,
  vSystemCPUs  : DWORD_PTR;

  bit          : DWORD_PTR;
  CPUs         : integer;
begin
  result := 0;
{$IF defined(NEED_PROCESS_AFFINITY_MASK)}
  *count = 1;
{$ELSE}
  if GetProcessAffinityMask (GetCurrentProcess ,
            &vProcessCPUs, &vSystemCPUs) then
  begin
    CPUs := 0;
    bit := 1;
    while ( bit <> 0) do
    begin
      if (vProcessCPUs and bit)>0 then begin
          Inc(CPUs);
        end;
      bit := bit shl 1; //bit <<= 1
    end;
    count^ := CPUs;
  end
  else
    begin
      result := EAGAIN;
    end;
{$ENDIF}

end;

function ptw32_relmillisecs(const abstime : Ptimespec):DWORD;
var
  milliseconds       : DWORD;
  tmpAbsNanoseconds,
  tmpCurrNanoseconds : int64;
  currSysTime        : timespec;
  ft                 : FILETIME;
  st                 : SYSTEMTIME;
  deltaNanoseconds   : int64;
begin
{$if defined(WINCE)}
   SYSTEMTIME st;
{$ENDIF}
  tmpAbsNanoseconds := abstime.tv_nsec + (abstime.tv_sec * NANOSEC_PER_SEC);

{$if defined(WINCE)}
  GetSystemTime(&st);
  SystemTimeToFileTime(&st, &ft);
{$else }
  GetSystemTimeAsFileTime(&ft);
{$ENDIF}
  ptw32_filetime_to_timespec(@ft, @currSysTime);
  tmpCurrNanoseconds := currSysTime.tv_nsec + (currSysTime.tv_sec * NANOSEC_PER_SEC);
  if tmpAbsNanoseconds > tmpCurrNanoseconds then
  begin
      deltaNanoseconds := tmpAbsNanoseconds - tmpCurrNanoseconds;
      if deltaNanoseconds >= int64_t (INFINITE * NANOSEC_PER_MILLISEC) then
         milliseconds := INFINITE - 1

      else
         milliseconds := DWORD(deltaNanoseconds div NANOSEC_PER_MILLISEC);

  end
  else
     milliseconds := 0;

  if (milliseconds = 0)  and  (tmpAbsNanoseconds > tmpCurrNanoseconds) then
     milliseconds := 1;

  Result := milliseconds;
end;

function ptw32_timed_eventwait(event : THANDLE;const abstime : Ptimespec):integer;
var
  milliseconds,
  status       : DWORD;
begin
  if Null = (event) then
      Exit(EINVAL)

  else
  begin
    if abstime = nil then
       milliseconds := INFINITE

    else
    begin

      milliseconds := ptw32_relmillisecs (abstime);
    end;
    status := WaitForSingleObject (event, milliseconds);
    if status <> WAIT_OBJECT_0 then
    begin
        if status = WAIT_TIMEOUT then
           Exit(ETIMEDOUT)

        else
          Exit(EINVAL);

    end;
  end;
  Exit(0);
end;

procedure ptw32_set_errno( err : integer);
begin
    _set_errno(err);
    SetLastError(err);
end;

procedure ptw32_mcs_node_transfer( new_node, old_node : Pptw32_mcs_local_node_t);
begin
  new_node.lock := old_node.lock;
  new_node.nextFlag := 0;
  new_node.readyFlag := 0;
  new_node.next := nil;
  if Pptw32_mcs_local_node_t (ptw32_INTERLOCKED_COMPARE_EXCHANGE_PTR (ptw32_INTERLOCKED_PVOID_PTR (new_node.lock)^,
                                                                          ptw32_INTERLOCKED_PVOID(new_node),
                                                                          ptw32_INTERLOCKED_PVOID(old_node)))
       <> old_node then
    begin

      while nil = old_node.next do
      begin
        sched_yield();
      end;

      ptw32_mcs_flag_wait(@old_node.nextFlag);

      new_node.next := old_node.next;
      new_node.nextFlag := old_node.nextFlag;
    end;
end;

procedure ptw32_mcs_lock_acquire( Alock : Pptw32_mcs_lock_t; node: Pptw32_mcs_local_node_t);
var
  pred : Pptw32_mcs_local_node_t;

begin
  node.lock := Alock;
  node.nextFlag := 0;
  node.readyFlag := 0;
  node.next := nil;


  pred := Pptw32_mcs_local_node_t (ptw32_INTERLOCKED_EXCHANGE_PTR (ptw32_INTERLOCKED_PVOID_PTR(Alock)^,
                                   ptw32_INTERLOCKED_PVOID(node)));
  if nil <> pred then
  begin

      ptw32_INTERLOCKED_EXCHANGE_PTR (ptw32_INTERLOCKED_PVOID_PTR(@pred.next)^,
                                      ptw32_INTERLOCKED_PVOID(node));
      ptw32_mcs_flag_set(@pred.nextFlag);
      ptw32_mcs_flag_wait(@node.readyFlag);
  end;
end;

function ptw32_semwait( sem : Psem_t):integer;
var
  node : ptw32_mcs_local_node_t;
  v : integer;
  s : sem_t;
begin
  result := 0;
  s := sem^;
  ptw32_mcs_lock_acquire(@s.lock, @node);
  Dec(s.value);
  v := s.value;
  ptw32_mcs_lock_release(@node);
  if v < 0 then
  begin

      if WaitForSingleObject (s.sem, INFINITE) = WAIT_OBJECT_0 then
      begin
{$IF defined(NEED_SEM)}
          ptw32_mcs_lock_acquire(&s.lock, &node);
          if s.leftToUnblock > 0 then
          begin
              Dec(s.leftToUnblock);
              SetEvent(s.sem);
          end;
          ptw32_mcs_lock_release(&node);
{$ENDIF}
          Exit(0);
      end;
  end
  else
    Exit(0);

  if result <> 0 then
  begin
       ptw32_SET_ERRNO(result);
      Exit(-1);
  end;
  Exit(0);
end;

procedure ptw32_throw( Aexception : DWORD);
var
  sp                   : Pptw32_thread_t;
  {$IF defined(ptw32_CLEANUP_SEH)}

  exceptionInformation : array[0..2] of DWORD;
  {$ENDIF}
  exitCode             : UInt32;
begin

  sp := Pptw32_thread_t (pthread_getspecific (g_ptw32_selfThreadKey));
  if sp <> nil then
     sp.state := PThreadStateExiting;

  if (Aexception <> ptw32_EPS_CANCEL) and (Aexception <> ptw32_EPS_EXIT) then
      halt (1);

  if (nil = sp)  or  (sp.implicit>0) then
  begin
{$IF defined (__MSVCRT__)  }
    exitCode := 0;
    case Aexception of
        ptw32_EPS_CANCEL:
        exitCode := uint32((size_t(PTHREAD_CANCELED)));
        //break;
        ptw32_EPS_EXIT:
        if nil <> sp then
          exitCode := uint32(size_t(sp.exitStatus));

    end;
{$ENDIF}
{$IF defined (ptw32_STATIC_LIB)}
      pthread_win32_thread_detach_np ();
{$ENDIF}
{$IF defined (__MSVCRT__)  and not  defined (FPC)}
    endthread (exitCode);

{$ELSE}
    endthread ();
{$ENDIF}
  end;

{$IF defined(ptw32_CLEANUP_SEH)}
  exceptionInformation[0] := DWORD (exception);
  exceptionInformation[1] := DWORD (0);
  exceptionInformation[2] := DWORD (0);
  RaiseException (EXCEPTION_ptw32_SERVICES, 0, 3,  @exceptionInformation);
{$elseif defined(ptw32_CLEANUP_C) }

  ptw32_pop_cleanup_all (1);
  longjmp(sp.start_mark, Aexception);
{$ELSEIF defined(ptw32_CLEANUP_CXX) }

  case exception of
    ptw32_EPS_CANCEL:
      throw ptw32_exception_cancel ();
      break;
    ptw32_EPS_EXIT:
      throw ptw32_exception_exit ();
      break;
    end;
{$ELSE}
   raise exception.Create(' Cleanup type undefined.');
{$ENDIF}

end;


procedure ptw32_pop_cleanup_all( execute : integer);
begin
  while nil <> ptw32_pop_cleanup (execute) do
    begin
    end;
end;


function ptw32_get_exception_services_code:DWORD;
begin
{$IF defined(ptw32_CLEANUP_SEH)}
  Exit(EXCEPTION_ptw32_SERVICES);
{$ELSE}
  Exit(DWORD(0));
{$ENDIF}
end;

procedure ptw32_cancel_self;
begin
  ptw32_throw(ptw32_EPS_CANCEL);
end;


function ptw32_Registercancellation( unused1 : PAPCFUNC; threadHandle : THANDLE; unused2 : DWORD):DWORD;
var
  context : TCONTEXT;
  s: string;
  P: ^DWORD_PTR;
begin
  context.ContextFlags := CONTEXT_CONTROL;
  GetThreadContext (threadHandle, &context);
  //s := Format('%p', [Addr(ptw32_cancel_self)]);
  P := Addr(ptw32_cancel_self);
  ptw32_PROGCTR (context, P^);
  SetThreadContext (threadHandle, &context);
  Result := 0;
end;

procedure ptw32_cancel_callback( unused : DWORD);//ULONG_PTR);
begin
  ptw32_throw(ptw32_EPS_CANCEL);
end;

function ptw32_pop_cleanup( execute : integer): Pptw32_cleanup_t;
var
  cleanup : Pptw32_cleanup_t;
begin

  if (not g_ptw32_processInitialized) then
    ptw32_processInitialize();

  cleanup := Pptw32_cleanup_t ( pthread_getspecific (g_ptw32_cleanupKey));
  if nil <> cleanup then
  begin

      if (execute > 0) and  Assigned(cleanup.routine) then
         cleanup.routine(cleanup.arg);

      pthread_setspecific (g_ptw32_cleanupKey, Pointer( cleanup.prev));
  end;
  Exit(cleanup);
end;


procedure ptw32_push_cleanup(cleanup : Pptw32_cleanup_t; routine : Tcleanup_callback_func; arg : Pointer);
begin

  if (not g_ptw32_processInitialized) then
    ptw32_processInitialize();

  cleanup.routine := routine;
  cleanup.arg := arg;
  cleanup.prev := Pptw32_cleanup_t ( pthread_getspecific (g_ptw32_cleanupKey));
  pthread_setspecific (g_ptw32_cleanupKey, Pointer(cleanup));
end;

function ptw32_threadReusePop:pthread_t;
var
  t : pthread_t;
  node : ptw32_mcs_local_node_t;
  tp: Pptw32_thread_t;
begin
  t.p := nil;
  t.x := 0;

  ptw32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
  if ptw32_THREAD_REUSE_EMPTY <> g_ptw32_threadReuseTop then
  begin

      tp := g_ptw32_threadReuseTop;
      g_ptw32_threadReuseTop := tp.prevReuse;
      if ptw32_THREAD_REUSE_EMPTY = g_ptw32_threadReuseTop then
         g_ptw32_threadReuseBottom := ptw32_THREAD_REUSE_EMPTY;

      tp.prevReuse := nil;
      t := tp.ptHandle;
  end;
  ptw32_mcs_lock_release(@node);
  Result := t;
end;

procedure ptw32_threadReusePush( thread : pthread_t);
var
  tp : Pptw32_thread_t;
  t : pthread_t;
  node : ptw32_mcs_local_node_t;
begin
  tp := Pptw32_thread_t ( thread.p);

  ptw32_mcs_lock_acquire(@g_ptw32_thread_reuse_lock, @node);
  t := tp.ptHandle;
  memset(tp, 0, sizeof(ptw32_thread_t));

  tp.ptHandle := t;

{$IF defined (ptw32_THREAD_ID_REUSE_INCREMENT)}
  tp.ptHandle.x  := tp.ptHandle.x + ptw32_THREAD_ID_REUSE_INCREMENT;
{$ELSE tp.ptHandle.PostInc(x);}
{$ENDIF}
  tp.state := PThreadStateReuse;
  tp.prevReuse := ptw32_THREAD_REUSE_EMPTY;
  if ptw32_THREAD_REUSE_EMPTY <> g_ptw32_threadReuseBottom then
      g_ptw32_threadReuseBottom.prevReuse := tp

  else
     g_ptw32_threadReuseTop := tp;

  g_ptw32_threadReuseBottom := tp;
  ptw32_mcs_lock_release(@node);
end;

procedure ptw32_threadDestroy( thread : pthread_t);
var
  tp          : Pptw32_thread_t;
  threadHandle,
  cancelEvent : THANDLE;
begin
  tp := Pptw32_thread_t ( thread.p);
  if tp <> nil then
  begin

{$IF defined (__MSVCRT__)  }
      threadHandle := tp.threadHandle;
{$ENDIF}
      cancelEvent := tp.cancelEvent;

      ptw32_threadReusePush (thread);
      if Null<>(cancelEvent) then
      begin
        CloseHandle (cancelEvent);
      end;
{$IF defined (__MSVCRT__)  }

      if threadHandle <> 0 then
         CloseHandle (threadHandle);

{$ENDIF}
end;
end;

function ptw32_cancelable_wait( waitHandle : THANDLE; timeout : DWORD):integer;
var
  self      : pthread_t;
  sp        : Pptw32_thread_t;
  handles   : array[0..1] of THANDLE;
  nHandles,
  status    : DWORD;
  stateLock : ptw32_mcs_local_node_t;
begin
  nHandles := 1;
  handles[0] := waitHandle;
  self := pthread_self();
  sp := Pptw32_thread_t ( self.p);
  if sp <> nil then
  begin

      if sp.cancelState = Int(PTHREAD_CANCEL_ENABLE) then
      begin
        handles[1] := sp.cancelEvent;
        if Null <> (handles[1]) then
           Inc(nHandles);

      end;
  end
  else
    handles[1] := null;

  status := WaitForMultipleObjects (nHandles, @handles, ptw32_FALSE, timeout);
  case status - WAIT_OBJECT_0 of
    0:
      result := 0;
      //break;
    1:
    begin
      ResetEvent (handles[1]);
      if sp <> nil then
      begin
        ptw32_mcs_lock_acquire (@sp.stateLock, @stateLock);
        if sp.state < PThreadStateCanceling then
        begin
            sp.state := PThreadStateCanceling;
            sp.cancelState := Int(PTHREAD_CANCEL_DISABLE);
            ptw32_mcs_lock_release (@stateLock);
            ptw32_throw  (ptw32_EPS_CANCEL);

        end;
        ptw32_mcs_lock_release (@stateLock);
      end;

      result := EINVAL;
    end;
    else
    begin
      if status = WAIT_TIMEOUT then
        result := ETIMEDOUT
      else
        result := EINVAL;
    end;

  end;

end;

procedure ptw32_tkAssocDestroy( assoc : PThreadKeyAssoc);
var
  prev, next : PThreadKeyAssoc;
begin
  if assoc <> nil then
  begin
      prev := assoc.prevKey;
      next := assoc.nextKey;
      if prev <> nil then begin
        prev.nextKey := next;
      end;
      if next <> nil then begin
        next.prevKey := prev;
      end;
      if assoc.thread.keys = assoc then begin

        assoc.thread.keys := next;
      end;
      if assoc.thread.nextAssoc = assoc then begin

        assoc.thread.nextAssoc := next;
      end;

      prev := assoc.prevThread;
      next := assoc.nextThread;
      if prev <> nil then begin
        prev.nextThread := next;
      end;
      if next <> nil then begin
        next.prevThread := prev;
      end;
      if assoc.key.threads = assoc then begin

        assoc.key.threads := next;
      end;
      free (assoc);
  end;
end;

function ptw32_robust_mutex_inherit( mutex : Ppthread_mutex_t):integer;
var
  n: LONG;
  mx : pthread_mutex_t;
  robust : Pptw32_robust_node_t;
begin
  mx := mutex^;
  robust := mx.robustNode;
  n := LONG(ptw32_INTERLOCKED_COMPARE_EXCHANGE_LONG(
             ptw32_INTERLOCKED_LONGPTR(@robust.stateInconsistent)^,
             ptw32_INTERLOCKED_LONG(ptw32_ROBUST_INCONSISTENT),
             ptw32_INTERLOCKED_LONG(-1 )));
  case n of

      -1:
          result := EOWNERDEAD;
          //break;
      LONG(ptw32_ROBUST_NOTRECOVERABLE):
          result := ENOTRECOVERABLE;
          //break;
      else
          result := 0;

  end;

end;


procedure ptw32_robust_mutex_add( mutex : Ppthread_mutex_t; self : pthread_t);
var
  list : __PPptw32_robust_node_t;
  mx : pthread_mutex_t;
  tp : Pptw32_thread_t;
  robust : Pptw32_robust_node_t;
begin
  mx := mutex^;
  tp := Pptw32_thread_t(self.p);
  robust := mx.robustNode;
  list := @tp.robustMxList;
  mx.ownerThread := self;
  if nil = list^ then
  begin
      robust.prev := nil;
      robust.next := nil;
      list^ := robust;
  end
  else
  begin
    robust.prev := nil;
    robust.next := list^;
    list^.prev := robust;
    list^ := robust;
  end;
end;


procedure ptw32_robust_mutex_remove( mutex : Ppthread_mutex_t; otp : Pptw32_thread_t);
var
  list : __PPptw32_robust_node_t;
  mx : pthread_mutex_t;
  robust : Pptw32_robust_node_t;
begin
  mx := mutex^;
  robust := mx.robustNode;
  list := @Pptw32_thread_t(mx.ownerThread.p).robustMxList;
  mx.ownerThread.p := otp;
  if robust.next <> nil then begin
      robust.next.prev := robust.prev;
    end;
  if robust.prev <> nil then begin
      robust.prev.next := robust.next;
    end;
  if list^ = robust then begin
     list^ := robust.next;
    end;
end;

procedure ptw32_mcs_flag_set(flag : PHANDLE);
var
  e : THANDLE;
begin

      e := ptw32_INTERLOCKED_COMPARE_EXCHANGE_SIZE(
           {$IFNDEF  WIn64}Pinteger(flag)^ {$ELSE} PInt64(flag)^ {$ENDIF}, -1, 0);
      if (THANDLE(0) <> e)  and  (THANDLE(-1) <> e) then
         SetEvent(e);


end;


procedure ptw32_mcs_flag_wait(flag : PHANDLE);
var
  e : THANDLE;
  n : Int64;
begin
  if 0 = ptw32_INTERLOCKED_EXCHANGE_ADD_SIZE (flag^, 0) then
  begin

    e := CreateEvent(nil,  ptw32_FALSE,  ptw32_FALSE, nil);
    //add by softwind 2021.12.24
    //SetEvent(e);
    if 0 =  ptw32_INTERLOCKED_COMPARE_EXCHANGE_SIZE(
              {$IFNDEF  WIn64}Pinteger(flag)^ {$ELSE} PInt64(flag)^ {$ENDIF}, e, 0)  then
       WaitForSingleObject(e, INFINITE);

    CloseHandle(e);
  end;
end;

procedure ptw32_mcs_lock_release( Anode : Pointer);//ptw32_mcs_local_node_t);
var
  lock : Pptw32_mcs_lock_t;
  next : Pptw32_mcs_local_node_t;
  p1: PPointer;
  Lnode : Pptw32_mcs_local_node_t;
begin

  Lnode := Pptw32_mcs_local_node_t (Anode);
  lock := Lnode.lock;
  next := Pptw32_mcs_local_node_t(ptw32_INTERLOCKED_EXCHANGE_ADD_SIZE(
                                     ptw32_INTERLOCKED_SIZEPTR(@Lnode.next)^, 0 ));

  if nil = next then
  begin
      p1 := PPointer(lock);
      if Anode = Pptw32_mcs_local_node_t (ptw32_INTERLOCKED_COMPARE_EXCHANGE_PTR (
                                              p1^,//ptw32_INTERLOCKED_PVOID_PTR(lock)^,
                                              nil,//ptw32_INTERLOCKED_PVOID(0),
                                              Anode) ) then
      begin

        exit;
      end;

      ptw32_mcs_flag_wait(@Lnode.nextFlag);


      next := Pptw32_mcs_local_node_t (ptw32_INTERLOCKED_EXCHANGE_ADD_SIZE (
                                           ptw32_INTERLOCKED_SIZEPTR(@Lnode.next)^,
                                            0));
  end
  else
     ptw32_mcs_flag_wait(@Lnode.nextFlag);

  ptw32_mcs_flag_set(@next.readyFlag);
end;

function ptw32_mcs_lock_try_acquire( lock : Pptw32_mcs_lock_t; node : Pptw32_mcs_local_node_t):integer;
var
  p: Pointer;
  vLock: ptw32_INTERLOCKED_PVOID_PTR;
begin
  node.lock := lock;
  node.nextFlag := 0;
  node.readyFlag := 0;
  node.next := nil;
  vLock := ptw32_INTERLOCKED_PVOID_PTR(lock);
  p := ptw32_INTERLOCKED_COMPARE_EXCHANGE_PTR (vLock^,
                                                 ptw32_INTERLOCKED_PVOID(node),
                                                 ptw32_INTERLOCKED_PVOID(0)
                                                );
   if ptw32_INTERLOCKED_PVOID(p) =  ptw32_INTERLOCKED_PVOID(0) then
      Result := 0
   else
      Result := EBUSY;
end;


end.
