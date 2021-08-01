{ Prj-Parameters.pas
Summary
    Export/import project parameters to/from ini file.
    Adds new paramters wuth value.
    Updates existing with new values if changed.

Added DemoAddNewParameters proc to show how to add parameters from ParameterList etc..

Author BL Miller
Date
18/09/2019 : 0.1  Initial POC .. seems to work
           : 0.11 Test the Import file has a valid Section before reading it!
19/09/2019 : 0.12 Code formatting & info text
20/05/2021 : 0.13 report variant info inc. comps & parameters of the variant & comps.
23/06/2021 : 0.14 Demo adding parameters to a variant.
  factor out TParameter
Are TParameterList methods broken in AD20+ ?


IniFiles are appended not reset ..

}

const
    cDummyTuples  = 'Area=51 | Answer=42 | Question=forgotten';        // spaces around the 'Name' will be trimmed.
    TopLevelKey   = 'PRJParameters';   // ini file section heading
    NoVariantName = 'No Variation';

Var
    WS           : IWorkSpace;
    IniFile      : TIniFile;
    Flag         : Integer;
    VersionMajor : WideString;
    ExtParas     : IExternalParameter;

function Version(const dummy : boolean) : TStringList;
begin
    Result := TStringList.Create;
    Result.Delimiter := '.';
    Result.Duplicates := dupAccept;
    Result.DelimitedText := Client.GetProductVersion;
end;

function ParameterExistsUpdateValue(Prj : IProject, Variant : TProjectVariant, PName : WideString, PValue : WideString, var existingvalue : widestring) : boolean;
var
    TempPara : TParameters;   //  DMObject TParameterAdapter
    I, J     : integer;
begin

    Result := false;
    if Variant <> nil then
    begin
        for I:= 0 to (Prj.DM_ProjectVariantCount - 1) do
        begin
            if Variant.DM_UniqueId =  Prj.DM_ProjectVariants(I).DM_UniqueId then
            begin

// variant parameters
                for J := 0 to (Variant.DM_ParameterCount - 1) do
                begin
                    TempPara := Variant.DM_Parameters(J);
                    if TempPara.DM_Name = PName then
                    begin
                        Result := true;                         // found para Name
                        existingvalue := TempPara.DM_Value;
//                        existingvalue := Variant.DM_CalculateParameterValue(TempPara);
                        if (existingvalue <>  PValue) then
                            TempPara.DM_SetValue(PValue);       // update value of existing
                    end;
                end;
            end;
        end;
    end else
    begin

        for I := 0 to (Prj.DM_ParameterCount - 1) do
        begin
            TempPara := Prj.DM_Parameters(I);
            if TempPara.DM_Name = PName then
            begin
                Result := true;                                // found para Name
                existingvalue := TempPara.DM_Value;
                if (existingvalue <>  PValue) then
                    TempPara.DM_SetValue(PValue);              // update value of existing
            end;
        end;

    end;
end;

Procedure DemoAddNewParameters;
var
    Prj           : IProject;
    Variant       : TProjectVariant;
    ParameterList : TParameterList;
    ParaSList     : TStringList;
    Parameter     : TParameter;
    PName         : WideString;
    OrigValue     : WideString;
    PValue        : WideString;
    I             : integer;

begin
   WS := GetWorkSpace;
   Prj := WS.DM_FocusedProject;
   if Prj = nil then exit;

   VersionMajor := Version(true).Strings(0);

{  broken in AD19+ or AD20+ ??
// ParameterLists
    ParameterList := TParameterList.Create;
    ParameterList.ClearAllParameters;
    ParameterList.SetState_FromString(cDummyTuples);

//  good for finding optional parameter text
    ParameterList.SetState_AddParameterAsString('Area','51');
    PName := 'Area';
    if ParameterList.GetState_ParameterAsString(PName, PVal) then
        ShowMessage('found in TPL:  '+ PName + ' = ' + PVal);
// or
    Parameter := ParameterList.GetState_ParameterByName(PName);      // this creates the TParameter object
    Parameter.Name; Parameter.Value;
// bad for indexing .Items(i) because that returns a pointer (DelphiScript is hopeless with pointers)
}

// StringList with delimited input & name value tuples.
    ParaSList := TStringList.Create;
    ParaSList.Delimiter       := '|';
    ParaSList.StrictDelimiter := true;
    ParaSList.Duplicates      := dupAccept;       //  dupIgnore
    ParaSList.DelimitedText   := cDummyTuples;

    Variant := nil;
    if Prj.DM_ProjectVariantCount > 0 then
        Variant := Prj.DM_ProjectVariants(Prj.DM_ProjectVariantCount - 1);

    for I := 0 to (ParaSList.Count - 1) do
    begin
        OrigValue := '';
        PName  := Trim(ParaSList.Names(I));
        PValue := ParaSList.ValueFromIndex(I);

        if ParameterExistsUpdateValue(Prj, Variant, PName, PValue, OrigValue) then
            ShowMessage('Found Existing parameter ' + PName + ' has old val= ' + OrigValue + ' & new val= ' + PValue)
        else
        begin
            Prj.DM_BeginUpdate;
            if Variant = nil then
                Prj.DM_AddParameter(PName, PValue)
            else
                Variant.DM_AddParameter(PName, PValue);

            Prj.DM_EndUpdate;
            ShowMessage('Added new para ' + PName + '  with val= ' + PValue);
        end;
    end;
    ParaSList.Clear;
    ParaSList.Free;

//    ParameterList.Destroy;

    Prj.DM_RefreshInWorkspaceForm;
end;

procedure ExportPrjParas(const Prj : IProject, const FileName : WideString);
var
    Parameter     : TParameter;
    ParaVariation : IParameterVariation;
    Variant       : TProjectVariant;
    VariantName   : WideString;
    VariantDesc   : Widestring;
    CompVar       : IComponentVariation;
    CurVarName    : WideString;
    VariantCount  : integer;
    VersionAll    : WideString;
    I, J, K       : integer;
    VarParaVal    : WideString;
    tmpStr        : WideString;

begin
    VersionMajor := Version(true).Strings(0);
    VersionAll   := Version(true).DelimitedText;

    Prj.DM_Compile;

    VariantName := NoVariantName;

    VariantCount := Prj.DM_ProjectVariantCount;

    Variant := Prj.DM_CurrentProjectVariant;
    if Variant <> Nil then
        VariantName := Variant.DM_Name;
     CurVarName := VariantName;

    IniFile := TIniFile.Create(FileName);

    IniFile.WriteString('ReleaseVersion', 'Altium',      VersionAll);
    IniFile.WriteString('Project', 'ProjectFileName',    Prj.DM_ProjectFileName);
    IniFile.WriteString('Project', 'ProjectKind' ,       Prj.DM_ObjectKindString);
    IniFile.WriteString('Project', 'VariantCount',       VariantCount);
    IniFile.WriteString('Project', 'CurrentVariant',     VariantName);
    IniFile.WriteString('Project', 'ParameterCount',     IntToStr(Prj.DM_ParameterCount) );

    for I:= 0 to (VariantCount - 1) do
    begin
        Variant :=  Prj.DM_ProjectVariants(I);

        Prj.DM_SetCurrentProjectVariant(Variant);
//        Prj.DM_Compile;
        VariantDesc := Variant.DM_Description;
        VariantName := Variant.DM_Name;
        IniFile.WriteString('ProjectVariants' +IntToStr(I), 'VariantName', VariantName);
        IniFile.WriteString('ProjectVariants' +IntToStr(I), 'VariantDesc', VariantDesc );
        IniFile.WriteString('ProjectVariants' +IntToStr(I), 'VariantParameterCount', IntToStr(Variant.DM_ParameterCount) );
// variant parameters
        for J := 0 to (Variant.DM_ParameterCount - 1) do
        begin
            Parameter := Variant.DM_Parameters(J);
            VarParaVal := Variant.DM_CalculateParameterValue(Parameter);
            IniFile.WriteString('ProjectVariants' + IntToStr(I) + 'Parameters', Parameter.DM_Name, VarParaVal);
        end;

// component variants
        IniFile.WriteString('ComponentVariation' + IntToStr(I), 'VariantCount', IntToStr(Variant.DM_VariationCount) );
        for J := 0  to (Variant.DM_VariationCount - 1) do
        begin
            CompVar := Variant.DM_Variations(J);
            CompVar.DM_LongDescriptorString;
            CompVar.DM_AlternatePart;
            CompVar.DM_VariationKind;

            IniFile.WriteString('ComponentVariation' + IntToStr(I), 'CompVarDesc' + IntToStr(J), CompVar.DM_LongDescriptorString );
            IniFile.WriteString('ComponentVariation' + IntToStr(I), 'CompVarKind' + IntToStr(J), IntToStr(CompVar.DM_VariationKind) );
            IniFile.WriteString('ComponentVariation' + IntToStr(I), 'AltComp' + IntToStr(J), CompVar.DM_AlternatePart);
            IniFile.WriteString('ComponentVariation' + IntToStr(I), 'CompVarCount' + IntToStr(J), IntToStr(CompVar.DM_VariationCount) );

// comp variant parameters
            for K := 0 to (CompVar.DM_VariationCount - 1) do
            begin
                 ParaVariation := CompVar.DM_Variations(K);
                 ParaVariation.DM_LongDescriptorString;
                 ParaVariation.DM_VariedValue;
                 ParaVariation.DM_ParameterName;
                 IniFile.WriteString('ComponentVariationParameters' + IntToStr(I), 'CVPDesc' + IntToStr(K), ParaVariation.DM_LongDescriptorString);
                 IniFile.WriteString('ComponentVariationParameters' + IntToStr(I), 'CVPName' + IntToStr(K), ParaVariation.DM_ParameterName);
                 IniFile.WriteString('ComponentVariationParameters' + IntToStr(I), 'CVPVal' + IntToStr(K),  ParaVariation.DM_VariedValue);
            end;
        end;
    end;

    for I := 0 to (Prj.DM_ParameterCount - 1) do
    begin
        Parameter := Prj.DM_Parameters(I);
        IniFile.WriteString(TopLevelKey, Parameter.DM_Name, Parameter.DM_Value );
{
            TempPara.DM_Description;
            TempPara.DM_ConfigurationName;
            TempPara.DM_Kind;
            TempPara.DM_RawText;
            TempPara.DM_LongDescriptorString;
            TempPara.DM_OriginalOwner;
            TempPara.DM_Visible;
 }
    end;
    IniFile.UpdateFile;
    IniFile.Free;
end;

procedure ImportPrjParas(const Prj : IProject, const FileName : WideString);
var
    Variant       : TProjectVariant;
    TuplesList    : TStringList;
    PName         : WideString;
    OrigValue     : WideString;
    PValue        : WideString;
    I             : integer;
    NewParameterCount : integer;
    ChangeValueCount  : integer;

begin
    IniFile    := TIniFile.Create(FileName);
    TuplesList := TStringList.Create;
    TuplesList.Delimiter := ',';
    TuplesList.NameValueSeparator := '=';
    TuplesList.Duplicates := dupIgnore;


//    Tuple := IniFile.ReadString(SectionName, VarName, DefaultValue );
//    IniFile.ReadSection(TopLevelKey, TuplesList);   // CDT block

    if IniFile.SectionExists(TopLevelKey) then
        IniFile.ReadSectionValues(TopLevelKey, TuplesList);
    IniFile.Free;

    NewParameterCount := 0;
    ChangeValueCount  := 0;
    Variant := nil;

    for I := 0 to (TuplesList.Count - 1) do
    begin
        OrigValue := '';
        PName  := Trim(TuplesList.Names(I));
        PValue := TuplesList.ValueFromIndex(I);

        if ParameterExistsUpdateValue(Prj, Variant, PName, PValue, OrigValue) then
        begin
            if OrigValue <> PValue then
            begin
                ShowMessage('Found Existing Parameter ' + PName + ' has old val= ' + OrigValue + ' & new val= ' + PValue);
                inc(ChangeValueCount);
            end;
        end
        else
        begin
            Prj.DM_BeginUpdate;
            Prj.DM_AddParameter(PName, PValue);
            Prj.DM_EndUpdate;
            inc(NewParameterCount);
            ShowMessage('Added new para ' + PName + '  with val= ' + PValue);
        end;
    end;

    if (TuplesList.Count > 0) then
    begin
        ShowMessage('Existing Parameter Value Change Count : ' + PadRight(IntToStr(ChangeValueCount), 3));
        if not (NewParameterCount = 0) then
            ShowMessage('New Parameter(s) Added Count : ' + PadRight(IntToStr(NewParameterCount), 3))
        else
            ShowMessage('ZERO New Parameters Added');
    end
    else ShowMessage('NO Parameter Section found !');

    TuplesList.Clear;
    Tupleslist.Free;
end;

// wrapper for direct call
procedure ExportProjectParameters;
var
    Prj         : IProject;
    SaveDialog  : TSaveDialog;
    FileName    : String;

begin
    WS := GetWorkSpace;
    Prj := WS.DM_FocusedProject;
    if Prj = nil then exit;
    FileName := Prj.DM_ProjectFullPath;

    SaveDialog        := TSaveDialog.Create(Application);
    SaveDialog.Title  := 'Export Project Parameters to *.ini file';
    SaveDialog.Filter := 'INI file (*.ini)|*.ini';
//    FileName := ExtractFilePath(Board.FileName);
    SaveDialog.FileName := ChangeFileExt(FileName, '-PrjPara.ini');

    Flag := SaveDialog.Execute;
    if (Flag = 0) then exit;
    FileName := SaveDialog.FileName;
    ExportPrjParas(Prj, FileName);
end;

// wrapper for direct call
procedure ImportProjectParameters;
var
    Prj         : IProject;
    OpenDialog  : TOpenDialog;
    FileName    : String;
begin
    WS := GetWorkSpace;
    Prj := WS.DM_FocusedProject;
    if Prj = nil then exit;
    FileName := Prj.DM_ProjectFullPath;

    OpenDialog        := TOpenDialog.Create(Application);
    OpenDialog.Title  := 'Import Project Parameters from *.ini file';
    OpenDialog.Filter := 'INI file (*.ini)|*.ini';
//    OpenDialog.InitialDir := ExtractFilePath(Board.FileName);
//  dialog uses windows internal mechanism to cache the previous use of Save or OpenDialog
    OpenDialog.FileName := '';
    Flag := OpenDialog.Execute;
    if (Flag = 0) then exit;

    FileName := OpenDialog.FileName;
    ImportPrjParas(Prj, FileName);
end;

{
TiniFiles
Each of the Read routines takes three parameters.
 - first identifies the section of the INI file.
 - second identifies the value you want to read
 - third is a default value in case the section or value doesn't exist in the INI file.
Similarly, the Write routines will create the section and/or value if they do not exist.

// ExtParas := IExternalParameter.DM_GetName('OriginalDate');
{
The IExternalParameter interface defines the external parameter object.
Interface Methods
Method                                  Description
Function  DM_GetSection : WideString;   Returns the Section string of the external parameter interface.
Function  DM_GetName : WideString;  Returns the Name string of the external parameter interface.
Function  DM_GetValue : WideString;     Returns the Value string of the external parameter interface.
Procedure DM_SetValue(AValue : WideString);     Sets the new value string for this external parameter.
}

