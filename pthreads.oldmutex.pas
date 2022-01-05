unit pthreads.oldmutex;

interface
uses pthreads.win, {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,

   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

  function old_mutex_lock( mutex : Pold_mutex_t):integer;
  function old_mutex_unlock( mutex : Pold_mutex_t):integer;
  function old_mutex_trylock( mutex : Pold_mutex_t):integer;

  function old_mutex_init(mutex : Pold_mutex_t;const attr : Pold_mutexattr_t):integer;
  function old_mutex_destroy( mutex : Pold_mutex_t):integer;

implementation

function old_mutex_destroy( mutex : Pold_mutex_t):integer;
var

  mx : old_mutex_t;
begin
  result := 0;
  if (mutex = nil ) or  (mutex^ = nil) then begin
      Exit(EINVAL);
    end;
  if mutex^ <> old_mutex_t ( PTW32_OBJECT_AUTO_INIT) then
  begin
      mx := mutex^;
      result := old_mutex_trylock(@mx);
      if result = 0 then
      begin
          mutex^ := nil;
          old_mutex_unlock(@mx);
          if mx.mutex = 0 then begin
              DeleteCriticalSection(mx.cs);
            end
          else
          begin
            if CloseHandle (mx.mutex)  then
               result := 0
            else
               result := EINVAL;
          end;
          if result = 0 then
          begin
              mx.mutex := 0;
              free(mx);
          end
          else

              mutex^ := mx;

      end;
  end
  else
    result := EINVAL;

  if Assigned(g_PTW32_try_enter_critical_section ) then
  begin
      FreeLibrary(g_PTW32_h_kernel32);
      g_PTW32_h_kernel32 := 0;
    end;

end;

function old_mutex_init(mutex : Pold_mutex_t;const attr : Pold_mutexattr_t):integer;
var

  mx : old_mutex_t;

  cs : TRTLCRITICALSECTION;
  label FAIL0 ;
begin
  result := 0;
  if mutex = nil then begin
      Exit(EINVAL);
    end;
  mx := old_mutex_t( calloc(1, sizeof( mx^)));
  if mx = nil then begin
      result := ENOMEM;
    end;
  mx.mutex := 0;
  if (attr <> nil) and  (attr^ <> nil)
       and  ( attr^.pshared = Int(PTHREAD_PROCESS_SHARED) )  then

  begin
    result := ENOSYS;
  end
  else
  begin
    begin
        InitializeCriticalSection(&cs);

        if TryEnterCriticalSection(cs) then
        begin
          LeaveCriticalSection(&cs);
        end
        else
        begin

          g_PTW32_try_enter_critical_section := nil;
        end;
        DeleteCriticalSection(&cs);
    end;

    if old_mutex_use = OLD_WIN32CS then
    begin
      InitializeCriticalSection(&mx.cs);
    end
    else
    if (old_mutex_use = OLD_WIN32MUTEX) then
    begin
         mx.mutex := CreateMutex (nil, FALSE,  nil);
         if mx.mutex = 0 then
            result := EAGAIN;

    end
    else
    begin
      result := EINVAL;
    end;
  end;
  if (result <> 0)  and  (mx <> nil) then
  begin
      free(mx);
      mx := nil;
  end;
FAIL0:
  mutex^ := mx;

end;

function old_mutex_lock( mutex : Pold_mutex_t):integer;
var

  mx : old_mutex_t;
begin
  result := 0;
  if (mutex = nil)  or  (mutex^ = nil) then begin
      Exit(EINVAL);
    end;
  if mutex^ = old_mutex_t (PTW32_OBJECT_AUTO_INIT) then
    begin

      result := EINVAL;
    end;
  mx := mutex^;
  if result = 0 then
  begin
      if mx.mutex = 0 then
      begin
        EnterCriticalSection(&mx.cs);
      end
      else
      begin
        if (WaitForSingleObject(mx.mutex, INFINITE) = WAIT_OBJECT_0) then
           result := 0
        else
           Result := EINVAL;
      end;
  end;

end;


function old_mutex_unlock( mutex : Pold_mutex_t):integer;
var

  mx : old_mutex_t;
begin
  result := 0;
  if (mutex = nil)  or  (mutex^ = nil) then begin
      Exit(EINVAL);
    end;
  mx := mutex^;
  if mx <> old_mutex_t( PTW32_OBJECT_AUTO_INIT)  then
    begin
      if mx.mutex = 0 then
      begin
        LeaveCriticalSection(&mx.cs);
      end
      else
      begin
        if ReleaseMutex (mx.mutex)  then
           result := 0
        else
           result := EINVAL;
      end;
    end
    else
    begin
      result := EINVAL;
    end;

end;


function old_mutex_trylock( mutex : Pold_mutex_t):integer;
var

  mx : old_mutex_t;
  status : DWORD;
begin
  result := 0;
  if (mutex = nil)  or  (mutex^ = nil) then begin
      Exit(EINVAL);
    end;
  if mutex^ = old_mutex_t  (PTW32_OBJECT_AUTO_INIT) then
    begin

      result := EINVAL;
    end;
  mx := mutex^;
  if result = 0 then
  begin
      if mx.mutex = 0 then
      begin
        if not Assigned(g_PTW32_try_enter_critical_section ) then
        begin
          result := 0;
        end
        else
        if g_PTW32_try_enter_critical_section(@mx.cs) <> TRUE then

            result := EBUSY;

      end
      else
      begin
        status := WaitForSingleObject (mx.mutex, 0);
        if status <> WAIT_OBJECT_0 then
        begin
          if (status = WAIT_TIMEOUT) then
             result := EBUSY
          else
             Result := EINVAL;
        end;
      end;
  end;

end;


end.
