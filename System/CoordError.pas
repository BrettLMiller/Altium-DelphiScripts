{ CoordToErrors.pas
   and VarTypes

Author BLMiller
20231209  POC
20231211  Add CoordRealMils & RealMMs output
}
const
    VarTypeMask = $0FFF;
    cValue      = 456;
var
    myVar  : Variant;
    Report : TStringList;

function ShowBasicVariantType(varVar: Variant) : WideString; forward;

procedure main;
var
    i, j : integer;
begin
    Report := TStringList.Create;
    Report.Add(Client.GetProductVersion);

  // Assign various values to a Variant
  // and then show the resulting Variant type
  ShowMessage('Variant value = not yet set is ' + ShowBasicVariantType(myVar) );

  // Simple value
  myVar := 123;
  ShowMessage('Variant value = 123 is ' + ShowBasicVariantType(myVar) );

  // Calculated value using a Variant and a constant
  myVar := myVar + cValue;
  ShowMessage('Variant value = 123 + const ' + IntToStr(cValue) + ' is ' + ShowBasicVariantType(myVar) );

  myVar := 'String ' + IntToStr(myVar);
  ShowMessage('Variant value = String of ' + myVar + ' is ' + ShowBasicVariantType(myVar) );

  myVar := cPI;
  ShowMessage('Variant value = pi is ' + ShowBasicVariantType(myVar) );

  myVar := CoordToMMs(10011);
  ShowMessage('Variant 10011 Coord= ' + FloatToStr(myVar) + 'mm is ' + ShowBasicVariantType(myVar) );
  myVar := CoordToMils(10011);
  ShowMessage('Variant 10011 Coord= ' + FloatToStr(myVar) + 'mil is ' + ShowBasicVariantType(myVar) );

//  kMaxCoord;
//  kMinCoord;
//  k1Mil;
//  cMaxWorkspaceSize;

//  MilsToRealCoord();
//  myVar := CoordToMMs_FullPrecision(10011);

//  ShowMessage('Variant 10011 Coord = ' + FloatToStr(myVar) + ShowBasicVariantType(myVar) );

  ShowMessage('Error of CoordToMMs in mm ' + FloatTostr( CoordToMMs_FullPrecision(10011) - CoordToMMs(10011) ));
  ShowMessage('Error of CoordToMils in Coord' + FloatTostr( (CoordToMils(10011) - (10011 / k1Mil)) * k1Mil ));
  ShowMessage('Error of CoordToMils in Coord' + FloatTostr( (CoordToMils(10009) - (10009 / k1Mil)) * k1Mil ));

    Report.Add('k1Mil' +'|'+ IntToStr(k1Mil));
    Report.Add('k1Inch' +'|'+ IntToStr(k1Inch));
    Report.Add('');
    Report.Add('val | CoordToMMs | CoordToMMs_FullPrecision |  /k1Inch * 25.4');
    for i := 0 to 100 do
    begin
        j := i * 1;
        Report.Add(IntToStr(j) + '|' + FloatTostr(CoordToMMs(j)) + '|' + FloatTostr(CoordToMMs_FullPrecision(j)) + '|' + FloatTostr(j / k1Inch * 25.4));
    end;

// returns rounded integer value
    Report.Add('');
    Report.Add('val | MMsToCoord | MMsToRealCoord() | *k1Inch / 25.4');
    for i := 0 to 100 do
    begin
        j := i * 1/100;
        Report.Add(IntToStr(j) + '|' + FloatTostr(MMsToCoord(j)) + '|' + FloatTostr(MMsToRealCoord(j)) + '|' +FloatTostr(j * k1Inch / 25.4));
    end;

    Report.Add('');
    Report.Add('val | CoordToMils |  CoordToRealMils | /k1Mil');

    for i := 0 to 100 do
    begin
        j := i * 107;
        Report.Add(IntToStr(j) + '|' + FloatTostr(CoordToMils(j))  + '|' + FloatTostr(MilsToRealCoord(j))+ '|' + FloatTostr(j / k1Mil) );
    end;
    Report.SaveToFile('c:\temp\CoordErrors.txt');
end;

// Show the type of a variant
function ShowBasicVariantType(varVar: Variant) : WideString;
var
  typeString : string;
  basicType  : Integer;

begin
  // Get the Variant basic type :
  // this means excluding array or indirection modifiers
  basicType := VarType(varVar) and VarTypeMask;

  // Set a string to match the type
  case basicType of
    varEmpty     : typeString := 'varEmpty';
    varNull      : typeString := 'varNull';
    varSmallInt  : typeString := 'varSmallInt';
    varInteger   : typeString := 'varInteger';
    varSingle    : typeString := 'varSingle';
    varDouble    : typeString := 'varDouble';
    varCurrency  : typeString := 'varCurrency';
    varDate      : typeString := 'varDate';
    varOleStr    : typeString := 'varOleStr';
    varDispatch  : typeString := 'varDispatch';
    varError     : typeString := 'varError';
    varBoolean   : typeString := 'varBoolean';
    varVariant   : typeString := 'varVariant';
    varUnknown   : typeString := 'varUnknown';
    varByte      : typeString := 'varByte';
    varWord      : typeString := 'varWord';
    varLongWord  : typeString := 'varLongWord';
    varInt64     : typeString := 'varInt64';
    varStrArg    : typeString := 'varStrArg';
    varString    : typeString := 'varString';
    varAny       : typeString := 'varAny';
    varTypeMask  : typeString := 'varTypeMask';
  end;

  Result := typeString;
  // Show the Variant type
//  ShowMessage('Variant type is '+typeString);
end;
