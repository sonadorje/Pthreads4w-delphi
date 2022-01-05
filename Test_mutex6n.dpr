program Test_mutex6n;

{$IFDEF FPC}
  {$MODE Delphi}//MacPas}

{$ENDIF}

{$APPTYPE CONSOLE}

{$R *.res}
{$DEFINE __PTW32_MUTEX_TYPES}
uses
{$IFnDEF FPC}
  System.SysUtils, System.Win.Crtl, Winapi.Windows,
{$ELSE}
  Sysutils, windows,
{$ENDIF}
  libc.Types in 'libc.Types.pas',
  pthreads.win in 'pthreads.win.pas';

var
  lockCount : integer;
  g_mutex     : pthread_mutex_t;
  g_mxAttr    : pthread_mutexattr_t;


function locker( arg : Pointer):Pointer;
begin
  assert(pthread_mutex_lock(&g_mutex) = 0);
  Inc(lockCount);
  { Should wait here (deadlocked) }
  assert(pthread_mutex_lock(&g_mutex) = 0);
  Inc(lockCount);
  assert(pthread_mutex_unlock(&g_mutex) = 0);
  Result := Pointer( 555);
end;

function ReturnValue(condition: Boolean; ret1, ret2: Integer): Integer;
begin
  if condition then
     result := ret1
  else
     RESULT := ret2;
end;

function main:integer;
var
  t : pthread_t;
  _i, _robust : integer;
  sz: Int;
  pma, pmaEnd : Ppthread_mutexattr_t;
  mxType : integer;
  s: string;
  function IS_ROBUST: integer;
  begin
     Result := ReturnValue(_robust=int(PTHREAD_MUTEX_ROBUST), 1,0);
  end;
begin
  mxType := -1;
  assert(pthread_mutexattr_init(g_mxAttr) = 0);
  //BEGIN_MUTEX_STALLED_ROBUST(g_mxAttr)
  _i := 0;
  while True do
  begin

    pthread_mutexattr_getrobust(@g_mxAttr, @_robust);
    lockCount := 0;
    assert(pthread_mutexattr_settype(g_mxAttr, Int(PTHREAD_MUTEX_NORMAL)) = 0);
    assert(pthread_mutexattr_gettype(@g_mxAttr, @mxType) = 0);
    assert(mxType = int(PTHREAD_MUTEX_NORMAL));
    assert(pthread_mutex_init(&g_mutex, @g_mxAttr) = 0);
    assert(pthread_create(@t, nil, locker, nil) = 0);
    while lockCount < 1 do
       Sleep(1);

    assert(lockCount = 1);
    assert(pthread_mutex_unlock(&g_mutex) = ReturnValue(IS_ROBUST>0,EPERM,0));
    while lockCount < ReturnValue(IS_ROBUST>0,1,2) do
          Sleep(1);

    assert(lockCount = ReturnValue(IS_ROBUST>0,1,2));
    //END_MUTEX_STALLED_ROBUST(g_mxAttr)
    if _robust=Int(PTHREAD_MUTEX_ROBUST) then
       s := 'Robust'
    else
       s := 'Non-robust';

    WriteLn(Format('Pass %s', [s]));
    Inc(_i);
    if _i  > 1 then
      break
    else
    begin

      pma := @g_mxAttr;
      sz := sizeof(g_mxAttr) div sizeof(pthread_mutexattr_t);
      pmaEnd := pma + sz;
      while pma < pmaEnd do
      begin
          pthread_mutexattr_setrobust(pma^, int(PTHREAD_MUTEX_ROBUST));
          Inc(pma);
      end;
    end;
    Result := 0;
  end;
end;


begin
  try
    main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
