unit pthreads.condattr;

interface
 uses pthreads.win, libc.Types;

function pthread_condattr_init(attr: Ppthread_condattr_t): Integer;

function pthread_condattr_destroy(attr: Ppthread_condattr_t): Integer;

function pthread_condattr_getpshared(const attr: Ppthread_condattr_t; pshared: PInteger): Integer;

function pthread_condattr_setpshared(attr: Ppthread_condattr_t; pshared: Integer): Integer;

implementation


function pthread_condattr_destroy( attr : Ppthread_condattr_t):integer;

begin
  result := 0;
  if (attr = nil)  or  (attr = nil) then
      result := EINVAL

  else
  begin
    free ( attr^);
    attr^ := nil;
    result := 0;
  end;
  Exit(result);
end;

function pthread_condattr_getpshared(const attr : Ppthread_condattr_t; pshared : Pinteger):integer;
begin
  if (attr <> nil)  and  (attr^ <> nil)   and  (pshared <> nil) then
  begin
    pshared^ :=  attr^.pshared;
    result := 0;
  end
  else
    begin
      result := EINVAL;
    end;
  Exit(result);
end;

function pthread_condattr_init( attr : Ppthread_condattr_t):integer;
var
  attr_result : pthread_condattr_t;

begin
  result := 0;
  attr_result := pthread_condattr_t( calloc (1, sizeof ( attr_result^)));
  if attr_result = nil then begin
      result := ENOMEM;
    end;
  attr^ := attr_result;
  Exit(result);
end;

function pthread_condattr_setpshared( attr : Ppthread_condattr_t; pshared : integer):integer;
begin
  if (attr <> nil)  and  (attr^ <> nil)  and
     ( (pshared = Int(PTHREAD_PROCESS_SHARED) ) or
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
         result := 0;

      attr^.pshared := pshared;
  end
  else
      result := EINVAL;

end;

end.
