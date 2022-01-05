unit pthreads.sched;

interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,

   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

function sched_yield(): Integer;
function sched_get_priority_min(policy: Integer): Integer;
function sched_getscheduler( pid : pid_t):integer;
function sched_get_priority_max(policy: Integer): Integer;

function sched_setscheduler(pid: pid_t; policy: Integer): Integer;

function sched_setaffinity(pid: pid_t; cpusetsize: NativeUInt; &set: Pcpu_set_t): Integer;

function sched_getaffinity(pid: pid_t; cpusetsize: NativeUInt; &set: Pcpu_set_t): Integer;

function _sched_affinitycpucount(const &set: Pcpu_set_t): Integer;


procedure _sched_affinitycpuzero(pset: Pcpu_set_t);

procedure _sched_affinitycpuset(cpu: Integer; pset: Pcpu_set_t);

procedure _sched_affinitycpuclr(cpu: Integer; pset: Pcpu_set_t);

function _sched_affinitycpuisset(cpu: Integer; const pset: Pcpu_set_t): Boolean;

procedure _sched_affinitycpuand(pdestset: Pcpu_set_t; const psrcset1: Pcpu_set_t; const psrcset2: Pcpu_set_t);

procedure _sched_affinitycpuor(pdestset: Pcpu_set_t; const psrcset1: Pcpu_set_t; const psrcset2: Pcpu_set_t);

procedure _sched_affinitycpuxor(pdestset: Pcpu_set_t; const psrcset1: Pcpu_set_t; const psrcset2: Pcpu_set_t);

function _sched_affinitycpuequal(const pset1: Pcpu_set_t; const pset2: Pcpu_set_t): Boolean;

function pthread_setschedparam(thread: pthread_t; policy: Integer; const param: Psched_param): Integer;

function pthread_getschedparam(thread: pthread_t; policy: PInteger; param: Psched_param): Integer;

implementation
uses pthreads.ptw32, pthreads.core;

function pthread_getschedparam( thread : pthread_t; policy : Pinteger; param : Psched_param):integer;
begin
  result := pthread_kill (thread, 0);
  if 0 <> result then begin
      Exit(result);
    end;
  if policy = nil then begin
      Exit(EINVAL);
    end;

  policy^ := Int(SCHED_OTHER);
  param.sched_priority := Pptw32_thread_t(thread.p).sched_priority;
  Result := 0;
end;

function sched_getaffinity( pid : pid_t; cpusetsize : NativeUInt; &set : Pcpu_set_t):integer;
var
  vProcessMask,
  vSystemMask  : DWORD_PTR;
  h            : THANDLE;
  targetPid    : Integer;

begin
  targetPid := int(size_t( pid));
  result := 0;
  if nil = &set then begin
    result := EFAULT;
    end
  else
    begin
{$IF not  defined(NEED_PROCESS_AFFINITY_MASK)}
    if 0 = targetPid then begin
      targetPid := int( GetCurrentProcessId );
    end;
    h := OpenProcess (PROCESS_QUERY_INFORMATION,  LongBool(PTW32_FALSE), DWORD( targetPid));
    //if VarIsNull( h) then
    if Null = ( h) then
    begin
      if ($FF and ERROR_ACCESS_DENIED) = GetLastError() then
         result := EPERM
      else
         Result := ESRCH;
    end
    else
    begin
    if GetProcessAffinityMask (h, &vProcessMask, &vSystemMask  )  then
      begin
        _Psched_cpu_set_vector_(&set)._cpuset := vProcessMask;
      end
      else
      begin
         result := EAGAIN;
      end;
    end;
    CloseHandle(h);
{$ELSE}
   _Psched_cpu_set_vector_(&set)._cpuset := size_t($1);
{$ENDIF}
    end;
  if result <> 0 then begin
     PTW32_SET_ERRNO(result);
    Exit(-1);
    end
  else

    Exit(0);

end;

function pthread_setschedparam(thread : pthread_t; policy : integer;const param : Psched_param):integer;
begin
  result := pthread_kill (thread, 0);
  if 0 <> result then begin
      Exit(result);
    end;

  if (policy < Int(SCHED_MIN))  or  (policy > Int(SCHED_MAX)) then begin
      Exit(EINVAL);
    end;

  if policy <> Int(SCHED_OTHER) then begin
      Exit(ENOTSUP);
    end;
  Result := (PTW32_setthreadpriority (thread, policy, param.sched_priority));
end;

function sched_yield:integer;
begin
  Sleep (0);
  Exit(0);
end;

function sched_get_priority_max( policy : integer):integer;
begin
  if (policy < Int(SCHED_MIN))  or  (policy > Int(SCHED_MAX)) then begin
       PTW32_SET_ERRNO(EINVAL);
      Exit(-1);
    end;
{$IF (THREAD_PRIORITY_LOWEST > THREAD_PRIORITY_NORMAL)}

  Exit(PTW32_MAX (THREAD_PRIORITY_IDLE, THREAD_PRIORITY_TIME_CRITICAL));
{$ELSE /}
  Exit(PTW32_MAX (THREAD_PRIORITY_IDLE, THREAD_PRIORITY_TIME_CRITICAL));
{$ENDIF}
end;

function sched_getscheduler( pid : pid_t):integer;
var
  selfPid : integer;
  h : THANDLE;
begin

  if 0 <> pid then begin
      selfPid := int( GetCurrentProcessId);
      if pid <> selfPid then
      begin
         h := OpenProcess (PROCESS_QUERY_INFORMATION,  LongBool(PTW32_FALSE), DWORD( pid));
          if Null = ( h) then
          begin
            if ($FF and ERROR_ACCESS_DENIED) = GetLastError() then
              PTW32_SET_ERRNO(EPERM)
            else
              PTW32_SET_ERRNO(ESRCH);
            Exit(-1);
          end
          else
            CloseHandle(h);
      end;
  end;
  Result := Int(SCHED_OTHER);
end;

function sched_setaffinity( pid : pid_t; cpusetsize : NativeUInt; &set : Pcpu_set_t):integer;
var
  vProcessMask,
  vSystemMask  : DWORD_PTR;
  h            : THANDLE;
  targetPid,

  newMask      : DWORD_PTR;
begin
{$IF not  defined(NEED_PROCESS_AFFINITY_MASK)}
  targetPid := int(size_t( pid));
  result := 0;
  if nil = &set then begin
    result := EFAULT;
  end
  else
  begin
    if 0 = targetPid then begin
      targetPid := int( GetCurrentProcessId);
    end;
    h := OpenProcess (PROCESS_QUERY_INFORMATION or PROCESS_SET_INFORMATION,  LongBool(PTW32_FALSE), DWORD( targetPid));
    if Null = ( h) then
    begin
      if ($FF and ERROR_ACCESS_DENIED) = GetLastError then
         result := EPERM
      else
         Result := ESRCH;
    end
    else
    begin
      if GetProcessAffinityMask (h, &vProcessMask, &vSystemMask ) then
      begin

        newMask := vSystemMask and (_Psched_cpu_set_vector_(&set))._cpuset;
        if newMask>0 then
        begin
          if SetProcessAffinityMask(h, newMask) = LongBool(0) then
          begin
            case (GetLastError()) of

                ($FF and ERROR_ACCESS_DENIED):
                  result := EPERM;

                ($FF and ERROR_INVALID_PARAMETER):
                  result := EINVAL;

                else
                  result := EAGAIN;


            end;
          end
          else
          begin
            result := EINVAL;
          end;
        end
        else
        begin
          result := EAGAIN;
        end;
    end;
    CloseHandle(h);
  end;
  if result <> 0 then begin
     PTW32_SET_ERRNO(result);
    Exit(-1);
    end
  else
      Exit(0);

{$ELSE PTW32_SET_ERRNO(ENOSYS);}
  Exit(-1);
{$ENDIF}
  end;
end;

function _sched_affinitycpucount(const &set : Pcpu_set_t):integer;
var
  tset : size_t;
  count : integer;
begin
  count := 0;
  tset := _Psched_cpu_set_vector_(&set)._cpuset;
  while ( tset>0 ) do
  begin
    if (tset and (size_t(1)))>0  then
       Inc(count);

    tset := tset shr  1;
  end;

  Result := count;
end;


procedure _sched_affinitycpuzero( pset : Pcpu_set_t);
begin
  _Psched_cpu_set_vector_(pset)._cpuset := size_t(0);
end;


procedure _sched_affinitycpuset( cpu : integer; pset : Pcpu_set_t);
begin
  _Psched_cpu_set_vector_(pset)._cpuset  := _Psched_cpu_set_vector_(pset)._cpuset  or (size_t(1)  shl  cpu);
end;


procedure _sched_affinitycpuclr( cpu : integer; pset : Pcpu_set_t);
begin
  _Psched_cpu_set_vector_(pset)._cpuset := _Psched_cpu_set_vector_(pset)._cpuset and
                                        not (size_t(1)  shl  cpu);
end;


function _sched_affinitycpuisset(cpu : integer;const pset : Pcpu_set_t):Boolean;
begin
  Result := (_Psched_cpu_set_vector_(pset)._cpuset and
      (size_t(1)  shl  cpu)) <> size_t(0);
end;


procedure _sched_affinitycpuand(pdestset : Pcpu_set_t;const psrcset1 : Pcpu_set_t;const psrcset2 : Pcpu_set_t);
begin
  _Psched_cpu_set_vector_(pdestset)._cpuset :=
      (_Psched_cpu_set_vector_(psrcset1)._cpuset and
          _Psched_cpu_set_vector_(psrcset2)._cpuset);
end;


procedure _sched_affinitycpuor(pdestset : Pcpu_set_t;const psrcset1 : Pcpu_set_t; const psrcset2 : Pcpu_set_t);
begin
  _Psched_cpu_set_vector_(pdestset)._cpuset :=
      (_Psched_cpu_set_vector_(psrcset1)._cpuset or
          _Psched_cpu_set_vector_(psrcset2)._cpuset);
end;


procedure _sched_affinitycpuxor(pdestset : Pcpu_set_t;const psrcset1 : Pcpu_set_t;const psrcset2 : Pcpu_set_t);
begin
  _Psched_cpu_set_vector_(pdestset)._cpuset :=
      (_Psched_cpu_set_vector_(psrcset1)._cpuset  xor
          _Psched_cpu_set_vector_(psrcset2)._cpuset);
end;


function _sched_affinitycpuequal(const pset1, pset2 : Pcpu_set_t):Boolean;
begin
  Result := _Psched_cpu_set_vector_(pset1)._cpuset =
      _Psched_cpu_set_vector_(pset2)._cpuset;
end;

function sched_get_priority_min( policy : integer):integer;
begin
  if (policy < Int(SCHED_MIN))  or  (policy > Int(SCHED_MAX)) then begin
       PTW32_SET_ERRNO(EINVAL);
      Exit(-1);
    end;
{$IF (THREAD_PRIORITY_LOWEST > THREAD_PRIORITY_NORMAL)}

  Exit(PTW32_MIN (THREAD_PRIORITY_IDLE, THREAD_PRIORITY_TIME_CRITICAL));
{$ELSE }
  Exit(PTW32_MIN (THREAD_PRIORITY_IDLE, THREAD_PRIORITY_TIME_CRITICAL));
{$ENDIF}
end;

function sched_setscheduler( pid : pid_t; policy : integer):integer;
var
  selfPid : integer;
  h : THANDLE;
begin

  if 0 <> pid then
  begin
      selfPid := int( GetCurrentProcessId );
      if pid <> selfPid then
      begin
        h := OpenProcess (PROCESS_SET_INFORMATION,  LongBool(PTW32_FALSE), DWORD(pid));
        if Null = ( h) then
        begin
           if (GetLastError = ($FF and ERROR_ACCESS_DENIED)) then
              PTW32_SET_ERRNO(EPERM)
           else
              PTW32_SET_ERRNO(ESRCH);
           Exit(-1);
        end
        else
      CloseHandle(h);
      end;
  end;
  if Int(SCHED_OTHER) <> policy then
  begin
       PTW32_SET_ERRNO(ENOSYS);
      Exit(-1);
  end;

  Result := Int(SCHED_OTHER);
end;

end.
