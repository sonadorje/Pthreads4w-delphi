unit pthreads.attr;

interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,

   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

function pthread_attr_destroy(attr: Ppthread_attr_t): Integer;
function pthread_attr_getaffinity_np(const attr: Ppthread_attr_t; cpusetsize: NativeUInt; cpuset: Pcpu_set_t): Integer;
function pthread_attr_getdetachstate(const attr: Ppthread_attr_t; detachstate: PInteger): Integer;
function pthread_attr_getinheritsched(const attr: Ppthread_attr_t; inheritsched: PInteger): Integer;
function pthread_attr_getname_np(attr: Ppthread_attr_t; name: PChar; len: Integer): Integer;
function pthread_attr_getschedparam(const attr: Ppthread_attr_t; param: Psched_param): Integer;
function pthread_attr_getschedpolicy(const attr: Ppthread_attr_t; policy: PInteger): Integer;
function pthread_attr_getscope(const attr: Ppthread_attr_t; contentionscope: PInteger): Integer;
function pthread_attr_getstackaddr(const attr: Ppthread_attr_t; stackaddr: PPointer): Integer;
function pthread_attr_getstacksize(const attr: Ppthread_attr_t; stacksize: PNativeUInt): Integer;
function pthread_attr_init(attr: Ppthread_attr_t):integer;
function pthread_attr_setaffinity_np(attr: Ppthread_attr_t; cpusetsize: NativeUInt; const cpuset: Pcpu_set_t): Integer;
function pthread_attr_setdetachstate(attr: Ppthread_attr_t; detachstate: Integer): Integer;
function pthread_attr_setinheritsched(attr: Ppthread_attr_t; inheritsched: Integer): Integer;
function pthread_attr_setschedparam(attr: Ppthread_attr_t; const param: Psched_param): Integer;
function pthread_attr_setschedpolicy(attr: Ppthread_attr_t; policy: Integer): Integer;
function pthread_attr_setstackaddr(attr: Ppthread_attr_t; stackaddr: Pointer): Integer;

implementation
uses pthreads.ptw32, pthreads.sched, pthreads.CPU;

function pthread_attr_setstacksize(attr: Ppthread_attr_t; stacksize: NativeUInt): Integer;
begin
{$IF _POSIX_THREAD_ATTR_STACKSIZE <> int64(-1)}
{$IF PTHREAD_STACK_MIN > 0}
  /
  if stacksize < PTHREAD_STACK_MIN then
  begin
      Exit(EINVAL);
  end;
{$ENDIF}
  if PTW32_is_attr (attr)  <> 0  then
    begin
      Exit(EINVAL);
    end;

  attr^.stacksize := stacksize;
  Exit(0);
{$ELSE}
  Exit(ENOSYS);
{$ENDIF}
end;

function pthread_attr_setstackaddr(attr: Ppthread_attr_t; stackaddr: Pointer): Integer;
begin
//{$IF _POSIX_THREAD_ATTR_STACKADDR <> int64(-1)}
{$IF _POSIX_THREAD_ATTR_STACKSIZE <> int64(-1)}
  if PTW32_is_attr (attr) <> 0 then
    begin
      Exit(EINVAL);
    end;
  attr^.stackaddr := stackaddr;
  Exit(0);
{$ELSE}
  Exit(ENOSYS);
{$ENDIF}
end;

function pthread_attr_setscope(attr: Ppthread_attr_t ; contentionscope : integer):integer;
begin
{$IF 0<(_POSIX_THREAD_PRIORITY_SCHEDULING)}
  case contentionscope of
    PTHREAD_SCOPE_SYSTEM:
      ( *attr).contentionscope = contentionscope;
      Exit(0);
    PTHREAD_SCOPE_PROCESS:
      Exit(ENOTSUP);
    else
      Exit(EINVAL);
    end;
{$ELSE}
   Exit(ENOSYS);
{$ENDIF}
end;

function pthread_attr_setschedpolicy(attr: Ppthread_attr_t; policy: Integer): Integer;
begin
  if PTW32_is_attr (attr)  <> 0 then
    begin
      Exit(EINVAL);
    end;
  if policy <> Int(SCHED_OTHER) then
  begin
      Exit(ENOTSUP);
    end;
  Result := 0;
end;


function pthread_attr_setschedparam(attr: Ppthread_attr_t; const param: Psched_param): Integer;
var
  priority : integer;
begin
  if (PTW32_is_attr (attr)  <> 0)  or  (param = nil) then
    begin
      Exit(EINVAL);
    end;
  priority := param.sched_priority;

  if (priority < sched_get_priority_min (Int(SCHED_OTHER)))  or
     ( priority > sched_get_priority_max (Int(SCHED_OTHER))) then
    begin
      Exit(EINVAL);
    end;
  memcpy (@attr^.param, param, sizeof ( param^));
  Result := 0;
end;

{$if defined (PTW32_COMPATIBILITY_BSD) or defined (PTW32_COMPATIBILITY_TRU64)}
function pthread_attr_setname_np(var name : byte; arg):integer;
var
  len, result : integer;
  tmpbuf : array[0..(PTHREAD_MAX_NAMELEN_NP)-1] of byte;
begin
  char * newname;
  char * oldname;
  /
  len := snprintf(tmpbuf, PTHREAD_MAX_NAMELEN_NP-1, name, arg);
  tmpbuf[PTHREAD_MAX_NAMELEN_NP-1] := #0;
  if len < 0 then begin
      Exit(EINVAL);
    end;
  newname := _strdup(tmpbuf);
  oldname := ( *attr).thrname;
  ( *attr).thrname = newname;
  if oldname then begin
      free(oldname);
    end;
  Result := 0;
end;
{$ELSE}
function pthread_attr_setname_np(attr: Ppthread_attr_t; const name: PChar): Integer;
var
  newname, oldname: PChar;
begin

  newname := strdup(name);
  oldname := attr^.thrname;
  attr^.thrname := newname;
  if Assigned(oldname) then
  begin
      free(oldname);
    end;
  Result := 0;
end;
{$ENDIF}

function pthread_attr_setinheritsched(attr: Ppthread_attr_t; inheritsched: Integer): Integer;
begin
  if PTW32_is_attr (attr)  <> 0 then
    begin
      Exit(EINVAL);
    end;
  if (Int(PTHREAD_INHERIT_SCHED) <> inheritsched) and
     (Int(PTHREAD_EXPLICIT_SCHED) <> inheritsched) then
  begin
      Exit(EINVAL);
  end;

  attr^.inheritsched := inheritsched;
  Result := 0;
end;


function pthread_attr_setdetachstate(attr: Ppthread_attr_t; detachstate: Integer): Integer;
begin
  if PTW32_is_attr (attr)  <> 0 then
    begin
      Exit(EINVAL);
    end;
  if (detachstate <> Int(PTHREAD_CREATE_JOINABLE) ) and
     (detachstate <> Int(PTHREAD_CREATE_DETACHED)) then
     begin
      Exit(EINVAL);
    end;
  attr^.detachstate := detachstate;
  Result := 0;
end;

function pthread_attr_setaffinity_np(attr: Ppthread_attr_t; cpusetsize: NativeUInt; const cpuset: Pcpu_set_t): Integer;
begin
  if (PTW32_is_attr (attr)  <> 0)  or  (cpuset = nil) then
    begin
      Exit(EINVAL);
    end;
  attr^.cpuset := _Psched_cpu_set_vector_(cpuset)._cpuset;
  Result := 0;
end;

function pthread_attr_init(attr: Ppthread_attr_t):integer;
var
  attr_result : pthread_attr_t;
  cpuset      : cpu_set_t;
begin
  if attr = nil then
  begin

      Exit(EINVAL);
    end;
  attr_result := pthread_attr_t( malloc (sizeof ( attr_result^)));
  if attr_result = nil then
  begin
      Exit(ENOMEM);
  end;
//{$IF int64(0)< _POSIX_THREAD_ATTR_STACKSIZE}
{$IF _POSIX_THREAD_ATTR_STACKSIZE > int64(0)}

  attr_result.stacksize := 0;
{$ENDIF}
{$IF 0<(_POSIX_THREAD_ATTR_STACKADDR)}

  attr_result.stackaddr := nil;
{$ENDIF}
  attr_result.detachstate := Integer(PTHREAD_CREATE_JOINABLE);
{$IF defined(HAVE_SIGSET_T)}
  memset (&(attr_result.sigmask), 0, sizeof (sigset_t));
{$ENDIF}

  attr_result.param.sched_priority := THREAD_PRIORITY_NORMAL;
  attr_result.inheritsched := Int(PTHREAD_EXPLICIT_SCHED);
  attr_result.contentionscope := Int(PTHREAD_SCOPE_SYSTEM);
  CPU_ZERO(@cpuset);
  attr_result.cpuset := _Psched_cpu_set_vector_(@cpuset)._cpuset;
  attr_result.thrname := nil;
  attr_result.valid := PTW32_ATTR_VALID;
  attr^ := attr_result;
  Result := 0;
end;


function pthread_attr_getstacksize(const attr: Ppthread_attr_t; stacksize: PNativeUInt): Integer;
begin
//{$IF _POSIX_THREAD_ATTR_STACKSIZE <> -1}
{$IF _POSIX_THREAD_ATTR_STACKSIZE <> int64(-1)}
  if PTW32_is_attr (attr)  <> 0  then
    begin
      Exit(EINVAL);
    end;

  stacksize^ := attr^.stacksize;
  Exit(0);
{$ELSE}
  Exit(ENOSYS);
{$ENDIF}
end;


function pthread_attr_getstackaddr(const attr: Ppthread_attr_t; stackaddr: PPointer): Integer;
begin
//{$IF _POSIX_THREAD_ATTR_STACKADDR <> -1}
{$IF _POSIX_THREAD_ATTR_STACKSIZE <> int64(-1)}
  if PTW32_is_attr (attr) <> 0  then
    begin
      Exit(EINVAL);
    end;
  stackaddr^ := attr^.stackaddr;
  Exit(0);
{$ELSE}
  Exit(ENOSYS);
{$ENDIF}
end;

function pthread_attr_getscope(const attr: Ppthread_attr_t; contentionscope: PInteger): Integer;
begin
{$IF defined(_POSIX_THREAD_PRIORITY_SCHEDULING)}
  *contentionscope = ( *attr).contentionscope;
  Exit(0);
{$ELSE}
  Exit(ENOSYS);
{$ENDIF}
end;

function pthread_attr_getschedpolicy(const attr: Ppthread_attr_t; policy: PInteger): Integer;
begin
  if (PTW32_is_attr (attr)  <> 0)  or  (policy = nil) then
    begin
      Exit(EINVAL);
    end;
  policy^ := Integer(SCHED_OTHER);
  Result := 0;
end;


function pthread_attr_getschedparam(const attr: Ppthread_attr_t; param: Psched_param): Integer;
begin
  if (PTW32_is_attr (attr)  <> 0)  or  (param = nil) then
    begin
      Exit(EINVAL);
    end;
  memcpy (param, @attr^.param, sizeof ( param^));
  Result := 0;
end;


function pthread_attr_getname_np(attr: Ppthread_attr_t; name: PChar; len: Integer): Integer;
begin
{$IF defined(_MSVCRT_)}
  strncpy(name, attr^.thrname, len - 1);
  attr^.thrname[len - 1] := #0;
{$ENDIF}
  Result := 0;
end;

function pthread_attr_getinheritsched(const attr: Ppthread_attr_t; inheritsched: PInteger): Integer;
begin
  if (PTW32_is_attr (attr)  <> 0)  or  (inheritsched = nil) then
    begin
      Exit(EINVAL);
    end;
  inheritsched^ := attr^.inheritsched;
  Result := 0;
end;


function pthread_attr_getdetachstate(const attr: Ppthread_attr_t; detachstate: PInteger): Integer;
begin
  if (PTW32_is_attr (attr) <> 0)  or  (detachstate = nil)  then
    begin
      Exit(EINVAL);
    end;
  detachstate^ := attr^.detachstate;
  Result := 0;
end;

function pthread_attr_destroy(attr: Ppthread_attr_t): Integer;
begin
  if PTW32_is_attr (attr)  <> 0  then
    begin
      Exit(EINVAL);
    end;

  attr^.valid := 0;
  free ( attr^);
  attr^ := nil;
  Result := 0;
end;

function pthread_attr_getaffinity_np(const attr: Ppthread_attr_t; cpusetsize: NativeUInt; cpuset: Pcpu_set_t): Integer;
begin
  if (PTW32_is_attr (attr) <> 0)  or  (cpuset = nil)  then
    begin
      Exit(EINVAL);
    end;
  _Psched_cpu_set_vector_(cpuset)._cpuset := attr^.cpuset;
  Result := 0;
end;

end.
