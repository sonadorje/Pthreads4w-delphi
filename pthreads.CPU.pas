unit pthreads.CPU;

interface
uses  pthreads.win, pthreads.sched;

procedure CPU_AND(destsetptr, srcset1ptr, srcset2ptr: Pointer);
function CPU_EQUAL(const set1ptr, set2ptr: Pcpu_set_t): Boolean;
function CPU_COUNT(setptr: Pcpu_set_t): Integer;
procedure CPU_SET(cpu : integer; setptr : Pcpu_set_t);
function CPU_ISSET(cpu : integer;const setptr : Pcpu_set_t): Boolean;
procedure CPU_CLR(cpu : integer; setptr : Pcpu_set_t);
procedure CPU_OR(pdestset : Pcpu_set_t;const psrcset1 : Pcpu_set_t; const psrcset2 : Pcpu_set_t);
procedure CPU_ZERO(setptr: Pcpu_set_t);inline;
procedure CPU_XOR(pdestset : Pcpu_set_t;const psrcset1 : Pcpu_set_t;const psrcset2 : Pcpu_set_t) ;

implementation

procedure CPU_ZERO(setptr: Pcpu_set_t);
begin
  _sched_affinitycpuzero(setptr);
end;

function CPU_ISSET(cpu : integer;const setptr : Pcpu_set_t): Boolean;
Begin
   Result := _sched_affinitycpuisset(cpu,setptr);
end;

procedure CPU_CLR(cpu : integer; setptr : Pcpu_set_t);
begin
   _sched_affinitycpuclr(cpu, setptr);
end;

procedure CPU_OR(pdestset : Pcpu_set_t;const psrcset1 : Pcpu_set_t; const psrcset2 : Pcpu_set_t);
begin
  _sched_affinitycpuor(pdestset,psrcset1, psrcset2);
end;

procedure CPU_XOR(pdestset : Pcpu_set_t;const psrcset1 : Pcpu_set_t;const psrcset2 : Pcpu_set_t) ;
begin
   _sched_affinitycpuxor(pdestset, psrcset1, psrcset2);
end;

procedure CPU_SET(cpu : integer; setptr : Pcpu_set_t);
begin
  _sched_affinitycpuset(cpu,setptr);
end;

procedure CPU_AND(destsetptr, srcset1ptr, srcset2ptr: Pointer);
begin
  _sched_affinitycpuand(destsetptr, srcset1ptr, srcset2ptr);
end;

function CPU_COUNT(setptr: Pcpu_set_t): Integer;
begin
  Result  := _sched_affinitycpucount(setptr);
end;
function CPU_EQUAL(const set1ptr, set2ptr: Pcpu_set_t): Boolean;
begin
   Result := _sched_affinitycpuequal(set1ptr,set2ptr);
end;

end.
