unit QueueUser_APCEx;

interface
uses pthreads.win, JwaWinIoctl,
 {$IFDEF FPC}
   sysutils, windows,  jwaiptypes, jwawindows,
 {$else}
   Winapi.Windows,

   System.Classes, System.SysUtils,
   System.Variants, System.Win.Crtl,
 {$endif}    libc.Types;

 function QueueUserAPCEx_Init:Boolean;
 function QueueUserAPCEx_Fini:Boolean;
 function QueueUserAPCEx( pfnApc : PAPCFUNC; hThread : THANDLE; dwData : DWORD):DWORD;

const
  FILE_DEVICE_ALERTDRV  = $00008005;
var
  hDevice: THANDLE  = INVALID_HANDLE_VALUE;

implementation

function IOCTL_ALERTDRV_SET_ALERTABLE2: DWORD;
begin
  Result := CTL_CODE(FILE_DEVICE_ALERTDRV, $800, METHOD_BUFFERED,
                     FILE_READ_ACCESS or FILE_WRITE_ACCESS);
end;

function QueueUserAPCEx_Init:Boolean;
begin

  hDevice := CreateFile('\\.\Global\ALERTDRV',
                    GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,
                    FILE_ATTRIBUTE_NORMAL, NULL);
  if (hDevice  = INVALID_HANDLE_VALUE)  then
  begin
    Writeln('QueueUserAPCEx_Init failed: Can''t get a handle to the ALERT driver');
    Exit(false);
  end;
  Result := True;
end;


function QueueUserAPCEx_Fini:Boolean;
begin
  Result := CloseHandle(hDevice);
end;


function QueueUserAPCEx( pfnApc : PAPCFUNC; hThread : THANDLE; dwData : DWORD):DWORD;
var
  cbReturned : DWORD;
  threadHandle: THandle;
begin
  threadHandle:=GetCurrentThread ();

  //if hThread = threadHandle then
  begin
    if  not QueueUserAPC(@pfnApc, hThread, dwData) then
        Exit(0);

    SleepEx(0, TRUE);
    Exit(1);
  end;

  if INVALID_HANDLE_VALUE = hDevice  then
   begin
      Writeln('Can''t get a handle to the ALERT driver');
      Exit(0);
   end;

  if SuspendThread(hThread) = -1    then
      Exit(0);


  if not QueueUserAPC(@pfnApc, hThread, dwData) then
     Exit(0);

  if DeviceIoControl (hDevice, DWORD (IOCTL_ALERTDRV_SET_ALERTABLE2), @hThread, sizeof(THANDLE),
                      nil, 0, &cbReturned, nil)  then
  begin
     //nothing
  end
  else
  begin
      Writeln('DeviceIoControl failed');
      Exit(0);
  end;

  ResumeThread(hThread);
  Result := 1;
end;
end.
