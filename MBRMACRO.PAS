{
MBR Macro

Program for manipulations of Master Boot Record of HDD, beforehand saved in file

Version 1.1

Compiled with Free Pascal

GNU License

(c) Artyomov Alexander

aralni[no spam]mail.ru
}

program MBRMakro;

type
	TPartNumb = 0..3;

type
        TFT01 = 0..1;            { True-False, One-Zero }
        TMyTimer = 0..9;         { My Timer Interval 0-off, 1..9 seconds }

type
	TMyRec = packed record
	pwd_on_timer	: byte; { 1bit pwd on(1), 3bit-not used, 4bit-timer(0-disable) }
	password	: array[1..8] of char;  { '12345678' }
	string_hint	: array[1..50] of char; { 'F1-12345678, F2-12345678, F3-12345678, F4-12345678' }
        boot_part       : byte; { 4bit NoLba, 2bit-NotUsed 2bit part for boot }
	end;
	PMyRec = ^TMyRec;

type
	TStdPartFields = packed record
	bBootFlag	: byte;	{ 0=not active, 80H = active (boot this partition) }
	bBeginHead	: byte;	{ partition begins at this head... }
	wBeginSecCyl	: word;	{ ...and this sector and cylinder (see below) }
	bFileSysCode	: byte;	{ file system type }
	bEndHead	: byte;	{ partition ends at this head... }
	wEndSecCyl	: word;	{ ...and this sector and cylinder (see below) }
	end;

	TLBAPartFields = packed record
	lBeginAbsSec	: dword; { partition begins at this absolute sector # }
	lTotalSects	: dword; { total sectors in this partition }
	end;

type
	TPartition = packed object
	StdFields : TStdPartFields;
        LBAFields : TLBAPartFields;
        end;

type
        TUID = packed record
	unused		: byte;
        Volume_ID       : dword;
	who_wrote	: byte;
        end;

type
        TMBR = packed record
        case byte of
        0:(
	Code		: array[1..440] of char;
        Id              : TUID;
	P		: array[TPartNumb] of TPartition;
	Signature	: word;
        );
        1:(
        mbr_as_bytes    : array[1..512] of byte;
        );
        2:(
        my_code         : array[1..380] of byte;
        MyRec           : TMyRec;
        Id_             : TUID;
        P_              : array[TPartNumb] of TPartition;
	Signature_      : word;
        );
        end;

  var
        OldPath         : string;
	Product, Temp   : TMBR;

const
	KeyWordsCount = 33;
	KeyWords : packed array[1..KeyWordsCount] of string =
	(
   {1}  'EXIT',                {Выйти из макроса}
   {2}  'REM',                 {Игнорировать строку}
   {3}  'WRITE',               {Вывести строку на экран}
   {4}  'RESET',               {Все байты у mbr обнулить, 55AA в конец}
   {5}  'INFO',                {Показать информацию об mbr}
   {6}  'DUMP',                {Показать дамп mbr}
   {7}  'SAVEPRODUCT',         {Сохранить получившийся mbr в файл}
   {8}  'LOAD',                {Загрузить mbr из файла}
   {9}  'GETALLPARTS',         {Загрузить таблицу разделов из файла}
   {10} 'GETPART',             {Загрузить указанный раздел целиком из файла}
   {11} 'GETPARTSTD',          {Загрузить указанный раздел из файла CHS+bf+fs}
   {12} 'GETPARTLBA',          {Загрузить указанный раздел из файла LBA}
   {13} 'GETID',               {Загрузить "уникальный номер диска" из файла}
   {14} 'GETCODE',             {Загрузить код загрузчика из файла}
   {15} 'GETPARTTYP',          {Загрузить тип указанного раздела из файла}
   {16} 'GETMYREC',            {Загрузить мои поля из файла}
   {17} 'SETPARTBEGINLENLBA',  {Установить начало - конец раздела в LBA}
   {18} 'SETPARTTYP',          {Установить тип раздела (файловой системы)}
   {19} 'SETPARTACTIVE',       {Установить или выключить загружаемость раздела}
   {20} 'SETMYOSNAMES',        {Установить строку с названиями систем}
   {21} 'SETMYBOOTPART',       {Установить систему по умолчанию}
   {22} 'SETMYTIMER',          {Установить интервал таймера в сек.1..9, 0-выкл.}
   {23} 'SETMYPASSWORDSTRING', {Установить строку пароля}
   {24} 'SETMYPASSWORDSTATUS', {Включить или выключить пароль}
   {25} 'SWAPPARTS',           {Поменять разделы местами}
   {26} 'SETID',               {Установить "уникальный номер винчестера"}
   {27} 'SETPARTBEGINCHS',     {Установить начало раздела (CHS)}
   {28} 'SETPARTENDCHS',       {Установить конец раздела (CHS)}
   {29} 'RESETPARTCHS',        {Обнулить значения CHS раздела}
   {30} 'CHSTOLBA',            {Пересчитать CHS в LBA раздела}
   {31} 'MYINFO',              {Показать информацию о моих полях}
   {32} 'EXPORT',              {Экспорт в текст}
   {33} 'IMPORT'               {Импорт (сейчас не реализованно)}
	);

function IntToStr(I:Longint) : string;
  var
	result : string;
begin
	Str(I, result);
	IntToStr := result;
end;

function StrToIntDef(S:String;Def:Longint) : Longint;
  var
	result, code : Longint;
begin
	Val(s, result, code);
	if code <> 0 then result := Def;
	StrToIntDef := result;
end;

function UpperCase(S:String) : String;
  var
	l, f : word;
	result : string;
begin result := s; l := Length(result); if l = 0 then exit;
  for f := 1 to l do result[f] := UpCase(result[f]);
  UpperCase := result;
end;

function NeatStr(s : string) : string;
label ExitNeatStr;
  var
	f, l   : integer;
	result : string;
begin result := '';    l := length(s);
if l > 0 then begin
for f := l downto 1 do if s[f] > #32 then break;
    s := copy(s, 1, f); if (f = 1) and (s[f] = ' ') then goto exitNeatStr;
for l := 1 to f do if s[l] > #32 then break;
     if l = 1 then result := s else
     result := copy(s, l, f - l + 1);
end; {end if}
ExitNeatStr:
 NeatStr := result;
end;

function BootTrue(v:TFT01) : byte;
begin
   if v = 1 then BootTrue := $80 else BootTrue := 0;
end;

function SaveProductToFile(FN : string) : boolean;
  var
      fp : file of TMBR;
begin if fn = '' then halt(3);
Assign(fp, fn);
ReWrite(fp);
Write(fp, Product);
Close(fp);
end;

function LoadMBRFromFile(FN : string) : boolean;
  var
      fp : file of TMBR;
begin if fn = '' then halt(3);
if OldPath = fn then exit;
Assign(fp, fn);
ReSet(fp);
Read(fp, Temp);
Close(fp);
OldPath := fn; // Save Old Path
end;

procedure ExportProduct(fn, rem : String);
  var
        fp : Text;
        f  : Longint;
begin
if fn <> '' then begin
Assign(fp, fn);
ReWrite(fp);
for f := 1 to 512 do WriteLn(fp, '$', HexStr(f-1, 4), '=$', HexStr(Product.mbr_as_bytes[f], 2));
writeln(fp, rem);
Close(fp);
end else for f := 1 to 512 do WriteLn('$', HexStr(f-1, 4), '=$', HexStr(Product.mbr_as_bytes[f], 2));
end;

procedure DisplayInfo;
  var
        f : longint;
begin
WriteLn;

for f := 0 to 3 do
WriteLn('Part ', f ,' LBA Begin, Len : ', Product.P[f].LBAFields.lBeginAbsSec, ' ($', HexStr(Product.P[f].LBAFields.lBeginAbsSec, 8), ') , ', Product.P[f].LBAFields.lTotalSects, ' ($', HexStr(Product.P[f].LBAFields.lTotalSects, 8), ')');

WriteLn;

for f := 0 to 3 do
WriteLn('Part ', f, ' BEGIN H:',
         Product.P[f].STDFields.bBeginHead, '($', HexStr(Product.P[f].STDFields.bBeginHead, 2) , ') SC:',
         Product.P[f].STDFields.wBeginSecCyl, '($', HexStr(Product.P[f].STDFields.wBeginSecCyl, 4), ') ',
         'END H:',
         Product.P[f].STDFields.bEndHead, '($', HexStr(Product.P[f].STDFields.bEndHead, 2), ') SC:',
         Product.P[f].STDFields.wEndSecCyl, '($', HexStr(Product.P[f].STDFields.wEndSecCyl, 4), ')');

WriteLn;

Write('File Systems: ');
for f := 0 to 3 do
Write('Part', f, ':',Product.P[f].STDFields.bFileSysCode, '($', HexStr(Product.P[f].STDFields.bFileSysCode, 2), ') ');

WriteLn;WriteLn;

Write('Part Bootable ($80-yes, $0-no): ');
for f := 0 to 3 do
Write('Part', f, ':', '$', HexStr(Product.P[f].STDFields.bBootFlag, 2), ' ');

WriteLn;WriteLn;

WriteLn('"Unique ID" of HDD: Unused:',Product.ID.unused, '($', HexStr(Product.ID.unused, 2) ,') ID:',Product.ID.Volume_ID,'($',HexStr(Product.ID.Volume_ID, 8),') Who Wrote ID:',Product.ID.who_wrote, '($', HexStr(Product.ID.who_wrote, 2), ')');

WriteLn;

end;
procedure DisplayMyInfo;
begin
writeln;
writeln('Systems names: ', String(Product.MyRec.string_hint));
writeln('Password string: ', String(Product.MyRec.password));
write('Password status: ');
if (Product.MyRec.pwd_on_timer and $80) = 0 then writeln('OFF') else writeln('ON');
writeln('Timer interval: ', (Product.MyRec.pwd_on_timer and not($80)));
writeln('Default system: ', Product.MyRec.boot_part);
WriteLn;
end;

function Base : boolean;
label ExitBase, ExitBaseErr;
  var
	InputString        : string;
	l, f, ff, anc      : integer;
	s1, s2, s3, s4     : string;
	parcnt, tmpb, Hmax, Smax        : byte;
        tmppart            : TPartition;
        ErrorOperator      : Boolean;
begin
s1 := ''; s2 := ''; s3 := ''; s4 := ''; parcnt := 0; anc := 1;
ErrorOperator := true;
readln(InputString);                           {read line}
InputString := neatstr(InputString);           {neat line}
l := Length(InputString);
if l = 0 then exit;
         {up case line}
// writeln(InputString);
{------------------------------------------------------------------------------}
for f := 1 to l do begin
  if InputString[f] = '<' then begin
	inc(parcnt);
	case parcnt of
		1: S1 := copy(InputString, anc, f - anc);
		2: S2 := copy(InputString, anc, f - anc);
		3: S3 := copy(InputString, anc, f - anc);
		4: begin S4 := copy(InputString, anc, l); break; end;
	end;
	anc := f;
	inc(anc);
  end; {end if}
end; {next f}
if parcnt = 0 then S1 := InputString;
if parcnt = 1 then S2 := copy(InputString, anc, l);
if parcnt = 2 then S3 := copy(InputString, anc, l);
if parcnt = 3 then S4 := copy(InputString, anc, l);
S1 := neatstr(S1);S2 := neatstr(S2);S3 := neatstr(S3);S4 := neatstr(S4);
S1 := UpperCase(S1);
{------------------------------------------------------------------------------}
// writeln('S1='+S1+' S2='+S2+' S3='+S3+' S4='+S4);
for f := 1 to KeyWordsCount do begin

if (S1 = KeyWords[f]) then begin
ErrorOperator := false;
   case f of
        1: HALT(0);
        2: break;
        3: writeln(copy(inputstring, 7, length(inputstring)));
        4: begin for ff := 1 to 510 do Product.mbr_as_bytes[ff] := 0; Product.mbr_as_bytes[511] := $55; Product.mbr_as_bytes[512] := $AA; end;
        5: DisplayInfo;
        6: begin
           for ff := 1 to 512 do begin
           if Product.mbr_as_bytes[ff] > 31 then write(Char(Product.mbr_as_bytes[ff])) else write('.');
           if (ff mod 80) = 0 then writeln; end;
           writeln;
           end;
        7: SaveProductToFile(S2);
        8: begin LoadMBRFromFile(S2); Product := Temp; end;
        9: begin LoadMBRFromFile(S2); Product.P := Temp.P; end;
       10: begin LoadMBRFromFile(S2); Product.P[StrToIntDef(S3, 255)] := Temp.P[StrToIntDef(S4, 255)]; end;
       11: begin LoadMBRFromFile(S2); Product.P[StrToIntDef(S3, 255)].StdFields := Temp.P[StrToIntDef(S4, 255)].StdFields; end;
       12: begin LoadMBRFromFile(S2); Product.P[StrToIntDef(S3, 255)].LBAFields := Temp.P[StrToIntDef(S4, 255)].LBAFields; end;
       13: begin LoadMBRFromFile(S2); Product.Id := Temp.Id; end;
       14: begin LoadMBRFromFile(S2); Product.Code := Temp.Code; end;
       15: begin LoadMBRFromFile(S2); Product.P[StrToIntDef(S3, 255)].StdFields.bFileSysCode := Temp.P[StrToIntDef(S4, 255)].StdFields.bFileSysCode; end;
       16: begin LoadMBRFromFile(S2); Product.MyRec := Temp.MyRec; end;
       17: begin Product.P[StrToIntDef(S2, 255)].LBAFields.lBeginAbsSec := StrToIntDef(S3, -1); Product.P[StrToIntDef(S2, 255)].LBAFields.lTotalSects := StrToIntDef(S4, -1); end;
       18: Product.P[StrToIntDef(S2, 255)].StdFields.bFileSysCode := StrToIntDef(S3, 1000);
       19: begin Product.P[StrToIntDef(S2, 255)].StdFields.bBootFlag := BootTrue(StrToIntDef(S3, 2)); end;
       20: begin if S2 = '' then halt(201);
       for ff := 1 to 50 do Product.MyRec.string_hint[ff] := ' ';
       for ff := 1 to Length(S2) do Product.MyRec.string_hint[ff] := S2[ff];
       end;
       21: TPartNumb(Product.MyRec.boot_part) := StrToIntDef(S2, 255);
       22: begin
       TMyTimer(tmpb) := StrToIntDef(S2, 255);
       Product.MyRec.pwd_on_timer := (Product.MyRec.pwd_on_timer and $80);
       Product.MyRec.pwd_on_timer := (Product.MyRec.pwd_on_timer or tmpb);
       end;
       23: begin if Length(S2) <> 8 then halt(201);
       for ff := 1 to 8 do Product.MyRec.password[ff] := S2[ff];
       end;
       24:  begin
       TFT01(tmpb) := StrToIntDef(S2, 255);
       tmpb := BootTrue(tmpb);
       Product.MyRec.pwd_on_timer := (Product.MyRec.pwd_on_timer and (not $80));
       Product.MyRec.pwd_on_timer := (Product.MyRec.pwd_on_timer or tmpb);
       end;
       25: begin tmppart := Product.P[StrToIntDef(S2, 255)];
                 Product.P[StrToIntDef(S2, 255)] := Product.P[StrToIntDef(S3, 255)];
                 Product.P[StrToIntDef(S3, 255)] := tmppart;
       end;
       26: begin Product.ID.unused := StrToIntDef(S2, -1);
                 Product.ID.Volume_ID := StrToIntDef(S3, -1);
                 Product.ID.who_wrote := StrToIntDef(S4, -1);
       end;
       27: begin
           Product.P[StrToIntDef(S2, 255)].StdFields.bBeginHead := StrToIntDef(S3, -1);
           Product.P[StrToIntDef(S2, 255)].StdFields.wBeginSecCyl := StrToIntDef(S4, -1);
       end;
       28: begin
           Product.P[StrToIntDef(S2, 255)].StdFields.bEndHead := StrToIntDef(S3, -1);
           Product.P[StrToIntDef(S2, 255)].StdFields.wEndSecCyl := StrToIntDef(S4, -1);
       end;
       29: begin Product.P[StrToIntDef(S2, 255)].StdFields.bBeginHead := 0;
                 Product.P[StrToIntDef(S2, 255)].StdFields.wBeginSecCyl := 0;
                 Product.P[StrToIntDef(S2, 255)].StdFields.bEndHead := 0;
                 Product.P[StrToIntDef(S2, 255)].StdFields.wEndSecCyl := 0;
       end;
       30: begin { Формула: LBA = (C * Hmax + H) * Smax + S - 1 }
       ff := Product.P[StrToIntDef(S2, 255)].StdFields.wBeginSecCyl;
       tmpb := lo(ff);
       tmpb := tmpb and 63; // clean cylinder
       ff := ff shr 6; // clean sector

       Hmax := StrToIntDef(S3, -1); Smax := StrToIntDef(S4, -1);

       Product.P[StrToIntDef(S2, 255)].LBAFields.lBeginAbsSec :=
       (tmpb * Hmax + Product.P[StrToIntDef(S2, 255)].StdFields.bBeginHead) *
       Smax + ff - 1;

       ff := Product.P[StrToIntDef(S2, 255)].StdFields.wEndSecCyl;
       tmpb := lo(ff);
       tmpb := tmpb and 63; // clean cylinder
       ff := ff shr 6; // clean sector

       Product.P[StrToIntDef(S2, 255)].LBAFields.lTotalSects :=
       (tmpb * Hmax + Product.P[StrToIntDef(S2, 255)].StdFields.bEndHead) *
       Smax + ff - 1;

       Product.P[StrToIntDef(S2, 255)].LBAFields.lTotalSects :=
       Product.P[StrToIntDef(S2, 255)].LBAFields.lTotalSects -
       Product.P[StrToIntDef(S2, 255)].LBAFields.lBeginAbsSec;
       end;
       31: DisplayMyInfo;
       32: ExportProduct(S2, S3);
       33: WriteLn('Currently no Import found.');
   end; {end select}
end; {end if}
end; {next f}
if ErrorOperator then begin writeln('Error operator: ', S1); halt(1); end;
{------------------------------------------------------------------------------}
end;

begin

        writeln;
        WriteLn('MBR Macro  Version 1.1  GNU License');
        WriteLn('   (c) 2004  Artyomov Alexander');
        WriteLn('      aralni[no spam]mail.ru');
        writeln;
        while not eof do begin
           base;
        end;  {wend}

end.
