unit libc.Types;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
{$IFnDEF FPC}

  Winapi.Windows, System.Win.Crtl, System.SysUtils, System.DateUtils, System.TypInfo, System.Math;
{$ELSE}
   Windows;
{$ENDIF}

const
  ECANCELED                 = 125;
  EPERM = 1;
  ENOENT = 2;
  ESRCH = 3;
  EINTR = 4;
  EIO = 5;
  ENXIO = 6;
  E2BIG = 7;
  ENOEXEC = 8;
  EBADF = 9;
  ECHILD = 10;
  EAGAIN = 11;
  ENOMEM = 12;
  EACCES = 13;
  EFAULT = 14;
  EBUSY = 16;
  EEXIST = 17;
  EXDEV = 18;
  ENODEV = 19;
  ENOTDIR = 20;
  EISDIR = 21;
  EINVAL = 22;
  ENFILE = 23;
  EMFILE = 24;
  ENOTTY = 25;
  EFBIG = 27;
  ENOSPC = 28;
  ESPIPE = 29;
  EROFS = 30;
  EMLINK = 31;
  EPIPE = 32;
  EDOM = 33;
  ERANGE = 34;
  EDEADLK = 36;
  ENOLCK = 39;
  ENOSYS = 40;
  EILSEQ = 42;
  EOWNERDEAD = 42;
  ENOTRECOVERABLE = 43;
  EDEADLOCK = EDEADLK;

  ETIMEDOUT = 10060;
  ENOTSUP = 48;
  { Minimum for largest signed integral type.  }
  INTMAX_MIN            = Int64(-Int64(9223372036854775807)-1);
  {$EXTERNALSYM INTMAX_MIN}
{ Maximum for largest signed integral type.  }
  INTMAX_MAX            = Int64(9223372036854775807);
  INT_MAX = $7fffffff;
  FOPEN_MAX	= 20;
  BUFSIZ = 1024;		(* size of buffer used by setbuf *)
  WCIO_UNGETWC_BUFSIZE = 1;
  SEEK_SET	=0;	(* set file offset to offset *)
	SEEK_CUR	=1;	(* set file offset to current plus offset *)
	SEEK_END	=2;	(* set file offset to EOF plus offset *)

 	__SLBF = $0001	       ;(*  line buffered *)
	__SNBF = $0002	       ;(*  unbuffered *)
	__SRD = $0004	       ;(*  OK to read *)
	__SWR = $0008	       ;(*  OK to write *)
       (*  RD and WR are never simultaneously asserted *)
	__SRW = $0010	       ;(*  open for reading & writing *)
	__SEOF = $0020	       ;(*  found EOF *)
	__SERR = $0040	       ;(*  found error *)
	__SMBF = $0080	       ;(*  _buf is from malloc *)
	__SAPP = $0100	       ;(*  fdopen()ed in append mode *)
	__SSTR = $0200	       ;(*  this is an sprintf/snprintf string *)
	__SOPT = $0400	       ;(*  do fseek() optimization *)
	__SNPT = $0800	       ;(*  do not do fseek() optimization *)
	__SOFF = $1000	       ;(*  set iff _offset is in fact correct *)
	__SMOD = $2000	       ;(*  true => fgetln modified _p text *)
	__SALC = $4000	       ;(*  allocate string space dynamically *)

  (*
 * Type ids for argument type table.
 *)
 T_UNUSED	=0;
 T_SHORT	=	1;
 T_U_SHORT	=2;
 TP_SHORT	=3;
 T_INT		=4;
 T_U_INT	=	5;
 TP_INT		=6;
 T_LONG		=7;
 T_U_LONG	=8;
 TP_LONG	=	9;
 T_LLONG	=	10;
 T_U_LLONG	=11;
 TP_LLONG	=12;
 T_DOUBLE	=13;
 T_LONG_DOUBLE	=14;
 TP_CHAR		=15;
 TP_VOID		=16;
 T_PTRINT	=17;
 TP_PTRINT	=18;
 T_SIZEINT	=19;
 T_SSIZEINT	=20;
 TP_SSIZEINT	=21;
 T_MAXINT	=22;
 T_MAXUINT	=23;
 TP_MAXINT	=24;
 _MSC_VER = 0;
 __MSVCRT_VERSION__= $0601;
type
  PClass = ^TClass;
  PPbyte = ^PByte;
  PPVarRec = ^PVarRec;
  PExceptionPointers = ^TExceptionPointers;
  PObject = ^TObject;
  uint16_t = uint16;
  int16_t = Int16;
  int8_t = Int8;
  uint8_t = UInt8;
  Puint8_t = ^uint8_t;
  uint64_t = Uint64;
  __int64_t = Int64;
  __off_t = __int64_t;
  off_t = __off_t;
  bool     = Boolean ;
  unsigned = UInt32;
  uint32_t = UInt32;
  int32_t  = int32;
  
  longlong = int64;
  Plonglong = ^longlong;
  ulonglong = UInt64;
  Pulonglong = ^ulonglong;
  ulong = Uint32;
  Pulong = ^ulong;
  PLong = ^long;
  short = SmallInt;
  Pshort = ^short;
  ushort = Word;
  Pushort = ^ushort;
  int = Integer;
  longdouble = Extended;
  float = Single;
  PAMQPChar = PByte;
  AMQPChar = AnsiChar;
  va_list = Array of TVarRec;
  Pva_list = ^va_list;
  PPva_list = ^Pva_list;
  (*According to the on-line docs (search for TVarRec), array of const
    parameters are treated like array of TVarRec by the compiler.*)
  ptrdiff_t = LongInt;
  intmax_t = Int64;
  __time64_t = Int64;
  Pintmax_t = ^intmax_t;
  {$IFDEF OS64}
  size_t = Uint64;
  ssize_t = int64;

  {$ELSE}
  size_t = uint32;
  Psize_t = ^size_t;
  ssize_t = int32;
  {$Endif}

   timeval = record
    tv_sec: Longint;
    tv_usec: Longint;
  end;
   TTimeVal = timeval;

  PTimeVal = ^TimeVal;

  timezone = {packed} record
    tz_minuteswest: Integer;    { Minutes west of GMT.  }
    tz_dsttime: Integer;        { Nonzero if DST is ever in effect.  }
  end;

  TTimeZone = timezone;
  PTimeZone = ^TTimeZone;

  _timeb = record

    time     : long;
    millitm,
    timezone,
    dstflag  : short;
  end;
  Ptimeb = ^_timeb;

  __timeb64 = record

    time      : __time64_t;
    millitm,
    timezone,
    dstflag   : byte;
  end;
{$if _MSC_VER >= 1400}
   //{$define  __PTW32_FTIME(x) _ftime64_s(x)
   __PTW32_STRUCT_TIMEB = __timeb64;
{$elseif ( _MSC_VER >= 1300 ) or ( (defined(__MINGW32__)) and (__MSVCRT_VERSION__ >= $0601 ))}
   //{$define  __PTW32_FTIME(x) _ftime64(x)
   __PTW32_STRUCT_TIMEB = __timeb64;
{$else}
   //{$define  __PTW32_FTIME(x) _ftime(x)
    __PTW32_STRUCT_TIMEB = _timeb ;
{$ifend}

  __sbuf = record
    _base: PByte;
    _size: int;
  end;

  __siov = record
    iov_base : pointer;
    iov_len  : size_t;
  end;
  __Psiov = ^__siov;

__suio = record

  uio_iov    : __Psiov;
  uio_iovcnt,
  uio_resid  : size_t;
end;
  __Psuio = ^__suio;

  Tfmemopen_cookie = record
    head, tail, cur, eob : Pchar;
  end;
  Pfmemopen_cookie = ^Tfmemopen_cookie;

  Tclose = function(p: Pointer): int;
  Pclose = ^Tclose;
  Tread = function(p1, p2: Pointer; size: size_t): ssize_t;
  Pread = ^Tread;
  //__off_t	(*_seek) (void *, __off_t, int);
  Tseek = function(p: Pointer; offset: __off_t; pos: int): __off_t;
  Pseek = ^Tseek;
  //ssize_t	(*_write)(void *, const void *, size_t);
  Twrite = function(p1: Pointer; const p2: Pointer; size: size_t): ssize_t;
  Pwrite = ^Twrite;
  //int	(*_flush)(void *);
  Tflush = function(p: Pointer): int;
  Pflush = ^Tflush;

__sFILE = record

  _p         :PByte;
  _r,
  _w         : integer;
  _flags     : short;
  _file      : short;
  _bf        : __sbuf;
  _lbfsize   : integer;
  _cookie    : pointer;
  _close     : Pclose;
  _read      : Pread;
  _seek      : Pseek;
  _write     : Pwrite;
  _ext       : __sbuf;
  _up        : PByte;
  _ur        : integer;
  _ubuf      : array[0..2] of byte;
  _nbuf      : array[0..0] of byte;
  _flush     : Pflush;
  (* Formerly used by fgetln/fgetwln; kept for binary compatibility *)
  _lb_unused : array[0..(sizeof(__sbuf) - sizeof(Tflush)-1)] of byte;
  _blksize   : integer;
  _offset    : __off_t;
end;

PFILE = ^__sFILE ;

mbstate_t = record
  __mbstateL : __int64_t;
  __mbstate8 : array[0..127] of byte;
end;
Pmbstate_t = ^mbstate_t;

wchar_io_data = record

  wcio_mbstate_in,
  wcio_mbstate_out   : mbstate_t;
  wcio_ungetwc_buf   : array[0..(WCIO_UNGETWC_BUFSIZE)-1] of WideChar;
  wcio_ungetwc_inbuf : size_t;
  wcio_mode          : integer;
end;
 Pwchar_io_data = ^wchar_io_data;




  Tcleanup = procedure ();
  Pcleanup = ^Tcleanup;

  Tfunction = function (fp: PFILE): int;
  Pfunction = ^Tfunction;

  Pglue = ^Tglue;
  Tglue = record

    next : Pglue;
    niobs : integer;
    iobs : PFILE;
  end;
  {
  TNullable<T: record> = record
    private
      FValue: T;
      FHasValue: Boolean;
      function  GetValue: T;
      procedure SetValue(AValue: T);
    public
      class operator Initialize(out Dest: TNullable<T>);

      property Value: T read FValue write SetValue;
      property HasValue: Boolean read FHasValue;
    end;
   }
  procedure free(P: Pointer);
  procedure memcpy(Dest: Pointer; const source: Pointer; count: Integer);

  function isdigit( c : integer):bool; overload; inline;
  Function IsDigit( ch: Char ): Boolean; overload; inline;
  Function IsAlpha( ch: Char ): Boolean; inline;
  Function IsUpper( ch:Char ): Boolean; inline;
  function IsSpace(Ch: Char): Boolean; inline;

  //function memchr(const buf: Pointer; c: Char; len: size_t): Pointer;
  function memchr(const bigptr: PChar; ch : Char; len : size_t): Pointer;

//  procedure memset(var X; Value: Integer; Count: NativeInt );
  procedure va_copy(orgap, ap: array of const);
  function PreDec(var n : integer): Integer; overload;
  function PreDec(var n : size_t): size_t;overload;
  //function to_digit(c: Char): Integer; inline;

  //function iswspace( wc : wint_t):integer;
  //function wcschr(__wcs: Pwchar_t; __wc: wchar_t): Pwchar_t;
  function strtoimax(nptr: PChar; endptr: PPChar; base: Integer): intmax_t;
  function malloc(size: uint32): Pointer;
  function strncpy(dst: PChar;const src : PChar; n : size_t):pchar;
  function strdup(const str : pchar):pchar;
  function calloc(Anum, ASize: Integer): Pointer;
  function _set_errno( n : integer):integer;
  function _get_errno(value: PInteger):integer;
  function get_result(result1, result2: Integer): Integer;inline; overload
  function get_result(condition: Boolean;result1, result2: integer): Integer; inline; overload;
  //function memcmp(const s1, s2 : Pointer; n : size_t):integer;

  function strncat(s1 : Pchar;const s2 : Pchar; n : size_t):Pchar;
  function strcpy(_to : Pchar; from : Pchar):Pchar;

  procedure interlocked_inc_with_conditionals( a : Pinteger);
  procedure interlocked_dec_with_conditionals( a : Pinteger);
  function strtoi(const nptr:PChar; endptr : PPChar; base : integer; lo, hi : intmax_t;rstatus : Pinteger):intmax_t;
var
  __errno, __sdidinit: int;
  __cleanup: Tcleanup ;
   usual: array[0..FOPEN_MAX - 3 - 1] of __sFILE;
  isInitialized: BOOL;


  __sglue: Tglue;


implementation

procedure interlocked_inc_with_conditionals( a : Pinteger);
begin
  if a <> nil then
    if InterlockedIncrement(PInteger( a)^) = -1 then
      begin
        a^ := 0;
      end;
end;


procedure interlocked_dec_with_conditionals( a : Pinteger);
begin
  if a <> nil then
     if InterlockedDecrement(PInteger( a)^) = -1 then
      begin
        a^ := 0;
      end;
end;


function strcpy(_to : Pchar; from : Pchar):Pchar;
var
  save : Pchar;
begin
  save := _to;
  while (from^ <> #0 ) do
  begin
    _to^ := from^;
    Inc(from);
    Inc(_to)
  end;
  Result := (save);
end;

//https://opensource.apple.com/source/Libc/Libc-262/ppc/gen/strncat.c.auto.html
function strncat(s1 : Pchar;const s2 : Pchar; n : size_t):Pchar;
var
  len1, len2 : uint32;
begin
    len1 :=length(s1);
    len2 := Length(s2);
    if len2 < n then
    begin
       strcpy (@s1[len1], s2);
    end
    else
    begin
      strncpy(@s1[len1], s2, n);
      s1[len1 + n] := #0;
    end;
    Result := s1;
end;

{
class operator TNullable<T>.Initialize(out Dest: TNullable<T>);
begin
  Dest.FHasValue := False;
end;

function TNullable<T>.GetValue: T;
begin
  if FHasValue then
    Result := FValue
  else
    raise Exception.Create('Invalid operation, Nullable type has no value');
end;

procedure TNullable<T>.SetValue(AValue: T);
begin
  FValue := AValue;
  FHasValue := True;
end;
}
//https://opensource.apple.com/source/Libc/Libc-167/string.subproj/memcmp.c.auto.html
{
function memcmp(const s1, s2 : Pointer; n : size_t):integer;
var
  p1, p2 : PByte;

  function IsNotEqual: Boolean;
  begin
     if p1^ <> P2^ then
        Result := True
     else
        Result := False;
     Inc(p1);
     Inc(p2);
  end;
begin
   p1 := s1;
   p2 := s2;
   if (n <> 0) then
   begin
      repeat
        if IsNotEqual then
        begin
          Dec(p1^); Dec(p2^);
          Exit(p1^ - p2^);
        end;


      until (PreDec(n) = 0);
   end;
    Exit(0);
end;
}
function get_result(condition: Boolean;result1, result2: integer): Integer;
begin
  if condition  then
     Result := Result1
  else
     Result := Result2;
end;

function get_result(result1, result2: integer): Integer;
begin
  if Result1 <> 0 then
     Result := Result1
  else
     Result := Result2;
end;

function _get_errno(value: PInteger):integer;
begin
   value^ := __errno;
   Result := 1;
end;


function _set_errno( n : integer):integer;
begin
    __errno := n;
    Result := -1;
end;

function calloc(Anum, ASize: Integer): Pointer;
begin
  Result := AllocMem(Anum*ASize);
end;

function strdup(const str : pchar):pchar;
var
  siz : size_t;
  copy : PChar;
begin
  siz := length(str) + 1;
  copy := malloc(siz);
  if copy = nil then
     Exit((nil));
  memcpy(copy, str, siz);
  Result := copy;
end;

function PreDec(var n : size_t): size_t;
begin
   Dec(n);
   Result := n;
end;

function PreDec(var n : integer): Integer;
begin
   Dec(n);
   Result := n;
end;

//bionic\libc\upstream-openbsd\lib\libc\string\strncpy.c
function strncpy(dst : PChar;const src : PChar; n : size_t):pchar;
var
  d, s : PChar;
  function IsZero: Boolean;
  begin
     d^ := s^;
     if d^ = #0 then
        Result := True
     else
        Result := False;
      Inc(d);
      Inc(s);
  end;
begin

  if n <> 0 then
  begin
    d := dst;
    s := src;

    repeat
      if IsZero then
      begin

        while PreDec(n) <> 0 do
        begin
          d^ := #0;
          Inc(d);

        end;
        break;

      end;
    until PreDec(n) = 0;

  end;
  Result := (dst);
end;

function malloc(size: uint32): Pointer;
begin
   Result := AllocMem(size);
end;

procedure va_copy(orgap, ap: array of const);
var
  i: Integer;
begin
  for I := Low(ap) to High(ap) do
      orgap[i] := ap[i];
end;



//https://opensource.apple.com/source/xnu/xnu-2782.30.5/bsd/libkern/memchr.c.auto.html
function memchr(const bigptr: PChar; ch : Char; len : size_t): Pointer;
var
  n : size_t;
  big: Pchar;
begin
  big := Pchar(bigptr);
  for n := 0 to len-1 do 
    if big[n] = ch then 
	   Exit(Pointer(@big[n]));
  Result := nil;
end;

{
function memchr(const buf: Pointer; c: Char; len: size_t): Pointer;
var
  l: Char;
begin
  Result := buf;
  l := c;
  while len <> 0 do
  begin
    if PChar(Result)[0] = l then
      Exit;
    Inc(Integer(Result));
    Dec(len);
  end;
  Result := Nil;
end;
}

Function IsAlpha( ch: Char ): Boolean;
begin
  Result := ch in ['a'..'z', 'A'..'Z']
end;

Function IsUpper( ch:Char ): Boolean;
begin
  Result := ch in ['A'..'Z']
end;

Function IsDigit( ch: Char ): Boolean;
Begin
  Result := ch In ['0'..'9'];
End;

function IsSpace(Ch: Char): Boolean;
begin
  Result := (Ch = #32) or (Ch = #$00A0); // Unicode non-breaking space
end;

//https://android.googlesource.com/platform/bionic.git/+/froyo/libc/stdlib/strtoimax.c
{ Like `strtol' but convert to `intmax_t'.  }
function strtoimax(nptr: PChar; endptr: PPChar; base: Integer): intmax_t;
var
  acc, cutoff : intmax_t;
  neg, any, cutlim : integer;
  s: PChar;
  c: Char;

  procedure CASE_BASE(x: Integer);
  begin
    //case x:
      if (neg>0) then
      begin
        cutlim := INTMAX_MIN mod x;
        cutoff := INTMAX_MIN div x;
      end
      else
      begin
        cutlim := INTMAX_MAX mod x;
        cutoff := INTMAX_MAX div x;
      end;
  end;

begin
  {
   * Skip white space and pick up leading +/- sign if any.
   * If base is 0, allow 0x for hex and 0 for octal, else
   }
  s := nptr;
  while isspace(c) do
  begin
    c := (s^);
    Inc(s);
  end;

  if c = '-' then
  begin
    neg := 1;
    c := s^;
    Inc(s);
  end
  else
  begin
    neg := 0;
    if c = '+' then
    begin
      c := s^;
      Inc(s);
    end;
  end;
  if ( (base = 0)  or  (base = 16) )  and
     (c = '0')  and  ( (s^ = 'x')  or  (s^ = 'X') ) then
  begin
    c := s[1];
    s  := s + 2;
    base := 16;
  end;
  if base = 0 then
     if c = '0' then
        base := 8
     else
        base := 10;
  {
   * Compute the cutoff value between legal numbers and illegal
   * numbers.  That is the largest legal value, divided by the
   * base.  An input number that is greater than this value, if
   * followed by a legal input character, is too big.  One that
   * between valid and invalid numbers is then based on the last
   * digit.  For instance, if the range for intmax_t is
   * [-9223372036854775808..9223372036854775807] and the input base
   * is 10, cutoff will be set to 922337203685477580 and cutlim to
   * either 7 (neg=0) or 8 (neg=1), meaning that if we have
   * accumulated a value > 922337203685477580, or equal but the
   * next digit is > 7 (or 8), the number is too big, and we will
   * return a range error.
   *
   * Set any if any `digits' consumed; make it negative to indicate
   * overflow.
   }
  { BIONIC: avoid division and module for common cases }
  case base of
     4:
     begin
        if neg>0 then
        begin
            cutlim := int(INTMAX_MIN mod 4);
            cutoff := INTMAX_MIN div 4;
        end
        else
        begin
            cutlim := int(INTMAX_MAX mod 4);
            cutoff := INTMAX_MAX div 4;
        end;
     end;
     8:
      CASE_BASE(8);
     10:
      CASE_BASE(10);
     16:
      CASE_BASE(16);
     else
     begin
        if neg > 0 then
           cutoff :=  INTMAX_MIN
        else
           cutoff := INTMAX_MAX;
        cutlim := cutoff mod base;
        cutoff  := cutoff  div base;
     end;
  end;
  if neg>0 then
  begin
    if cutlim > 0 then
    begin
      cutlim  := cutlim - base;
      cutoff  := cutoff + 1;
    end;
    cutlim := -cutlim;
  end;

  acc := 0;
  any := 0;

  while True do
  begin
    c := s^;
    if isdigit(c) then
      c  := Chr(Ord(c) - Ord('0'))
    else
    if (isalpha(c)) then
    begin
      if isupper(c) then
         c  := Chr(Ord(c) - (Ord('A') - 10 ))
      else
         c  := Chr(Ord(c) - (Ord('a') - 10));
    end
    else
      break;
    if Ord(c) >= base then
       break;
    if any < 0 then
       continue;
    if neg>0 then
    begin
      if (acc < cutoff)  or  ( (acc = cutoff)  and  (Ord(c) > cutlim) ) then
      begin
        any := -1;
        acc := INTMAX_MIN;
        __errno := ERANGE;
      end
      else
      begin
        any := 1;
        acc  := acc  * base;
        acc  := acc - Ord(c);
      end;
    end
    else
    begin
      if (acc > cutoff)  or  ( (acc = cutoff)  and  (Ord(c) > cutlim) ) then
      begin
        any := -1;
        acc := INTMAX_MAX;
        __errno := ERANGE;
      end
      else
      begin
        any := 1;
        acc  := acc  * base;
        acc  := acc + Ord(c);
      end;
    end;
    Inc(s);
  end;
  //if (endptr != 0)
  if endptr <> nil then
     if any>0 then
        endptr^ := Pchar(s - 1)
     else
        endptr^ := Pchar(nptr);
  Result := (acc);
end;


//https://android.googlesource.com/platform/external/dhcpcd-6.8.2/+/refs/tags/android-7.0.0_r6/compat/strtoi.c
function strtoi(const nptr:PChar; endptr : PPChar; base : integer; lo, hi : intmax_t;rstatus : Pinteger):intmax_t;
var
  serrno : integer;
  r : intmax_t;
  ep : PChar;
  rep : integer;
begin
  if endptr = nil then
     endptr := @ep;
  if rstatus = nil then
     rstatus := @rep;
  serrno := __errno;
  __errno := 0;
  r := strtoimax(nptr, endptr, base);
  rstatus^ := __errno;
  __errno := serrno;
  if rstatus^ = 0 then
  begin
    if nptr = endptr^ then
      rstatus^ := ECANCELED
    else
    if ( endptr^^ <> #0) then
      rstatus^ := ENOTSUP;
  end;

  if r < lo then
  begin
    if rstatus^ = 0 then
      rstatus^ := ERANGE;
    Exit(lo);
  end;
  if r > hi then
  begin
    if rstatus^ = 0 then
      rstatus^ := ERANGE;
    Exit(hi);
  end;
  Result := r;
end;


//https://github.com/embeddedartistry/libc
//libc-master\src\ctype
function isdigit( c : integer):bool;
begin
  Result := Cardinal(c - ord('0')) < 10;
end;

procedure memcpy(Dest: Pointer; const source: Pointer; count: Integer);
begin
   move(Source^,Dest^, Count);
end;

procedure free(P: Pointer);
begin
   FreeMemory(P);
end;

initialization
  isInitialized := False;

end.
