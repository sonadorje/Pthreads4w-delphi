unit pthreads.mutexattr;

interface
uses pthreads.win, libc.Types;

function pthread_mutexattr_init(var attr: pthread_mutexattr_t): Integer;

function pthread_mutexattr_destroy(attr: Ppthread_mutexattr_t): Integer;

function pthread_mutexattr_getpshared(const attr: Ppthread_mutexattr_t; pshared: PInteger): Integer;

function pthread_mutexattr_setpshared(attr: Ppthread_mutexattr_t; pshared: Integer): Integer;

function pthread_mutexattr_settype(var attr: pthread_mutexattr_t; kind: Integer): Integer;

function pthread_mutexattr_gettype(const attr: Ppthread_mutexattr_t; kind: PInteger): Integer;

function pthread_mutexattr_setrobust(var attr: pthread_mutexattr_t; robust: Integer): Integer;

function pthread_mutexattr_getrobust(const attr: Ppthread_mutexattr_t; robust: PInteger): Integer;
function pthread_mutexattr_setkind_np(attr: Ppthread_mutexattr_t; kind: Integer): Integer;

function pthread_mutexattr_getkind_np(attr: Ppthread_mutexattr_t; kind: PInteger): Integer;


implementation


//uses pthreads.win;

function pthread_mutexattr_settype(var attr : pthread_mutexattr_t; kind : integer):integer;
begin
  result := 0;
  if (attr <> nil)  then
  begin
    case kind of
      Int(PTHREAD_MUTEX_FAST_NP),
      Int(PTHREAD_MUTEX_RECURSIVE_NP),
      Int(PTHREAD_MUTEX_ERRORCHECK_NP):
        attr.kind := kind;

    else
      result := EINVAL;

    end;
  end
  else
     result := EINVAL;


end;

function pthread_mutexattr_setrobust(var attr : pthread_mutexattr_t; robust : integer):integer;
begin
  result := EINVAL;
  if (attr <> nil) then
    begin
      case robust of
          Int(PTHREAD_MUTEX_STALLED),
          Int(PTHREAD_MUTEX_ROBUST):
          begin
            attr.robustness := robust;
            result := 0;
          end;
      end;
    end;

end;

function pthread_mutexattr_setpshared( attr : Ppthread_mutexattr_t; pshared : integer):integer;
begin
  if (attr <> nil)  and  (attr^ <> nil)   and
      ((pshared = Int(PTHREAD_PROCESS_SHARED))  or
       (pshared = Int(PTHREAD_PROCESS_PRIVATE)))  then
    begin
      if pshared = Int(PTHREAD_PROCESS_SHARED) then
      begin
    {$IF not defined( _POSIX_THREAD_PROCESS_SHARED )}
        result := ENOSYS;
        pshared := Int(PTHREAD_PROCESS_PRIVATE);
    {$ELSE}
        result = 0;
    {$ENDIF}
      end
      else
        result := 0;

      attr^.pshared := pshared;
  end
  else
     result := EINVAL;

end;

function pthread_mutexattr_setkind_np( attr : Ppthread_mutexattr_t; kind : integer):integer;
begin
  Result := pthread_mutexattr_settype (attr^, kind);
end;

function pthread_mutexattr_init(var attr : pthread_mutexattr_t):integer;
var

  ma : pthread_mutexattr_t;
begin
  result := 0;
  ma := pthread_mutexattr_t( calloc (1, sizeof (ma^)));
  if ma = nil then begin
      result := ENOMEM;
    end
  else
    begin
      ma.pshared := Int(PTHREAD_PROCESS_PRIVATE);
      ma.kind := Int(PTHREAD_MUTEX_DEFAULT);
      ma.robustness := Int(PTHREAD_MUTEX_STALLED);
    end;
  attr := ma;

end;

function pthread_mutexattr_gettype(const attr : Ppthread_mutexattr_t; kind : Pinteger):integer;
begin
  result := 0;
  if (attr <> nil)  and  (attr^ <> nil)  and  (kind <> nil) then
    kind^ := attr^.kind

  else

      result := EINVAL;
end;

function pthread_mutexattr_getrobust(const attr : Ppthread_mutexattr_t; robust : Pinteger):integer;
begin
  result := EINVAL;
  if (attr <> nil)  and  (attr^ <> nil)  and  (robust <> nil)  then
    begin
      robust^ := attr^.robustness;
      result := 0;
    end;

end;

function pthread_mutexattr_getpshared(const attr : Ppthread_mutexattr_t; pshared : Pinteger):integer;
begin
  if (attr <> nil)  and  (attr^ <> nil)   and  (pshared <> nil) then
  begin
    pshared^ := attr^.pshared;
    result := 0;
  end
  else
    result := EINVAL;


end;

function pthread_mutexattr_getkind_np( attr : Ppthread_mutexattr_t; kind : Pinteger):integer;
begin
  Result := pthread_mutexattr_gettype (attr, kind);
end;

function pthread_mutexattr_destroy( attr : Ppthread_mutexattr_t):integer;
var

  ma : pthread_mutexattr_t;
begin
  result := 0;
  if (attr = nil)  or  (attr^ = nil) then
      result := EINVAL

  else
  begin
    ma := attr^;
    attr^ := nil;
    free (ma);
  end;
  Result := (result);
end;

end.
