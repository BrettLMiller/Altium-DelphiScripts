{.............................................................................
  CountSymbolPins.pas
  SchLib & SchDoc
  Count pins of all parts of Symbols
  Report part cnt & pin xy & len

  Disabled --> Save as parameter to allow use by FSO/Inspector

 from Altium Summary Demo how to iterate through a schematic library.

 Version 1.0
 BL Miller
17/04/2020  v1.10  added pin x, y & len
04/03/2021  v1.20  added all parts & modes & support SchDoc
16/04/2021  v1.21  improved multi-part designator
..............................................................................}

const
    bDisplay      = true;
    bAddParameter = false;

Procedure GenerateReport(Report : TStringList, Filename : WideString);
Var
    WS       : IWorkspace;
    Prj      : IProject;
    Document : IServerDocument;
    Filepath : WideString;

Begin
    WS  := GetWorkspace;
    If WS <> Nil Then
    begin
       Prj := WS.DM_FocusedProject;
       If Prj <> Nil Then
          Filepath := ExtractFilePath(Prj.DM_ProjectFullPath);
    end;
    
    If length(Filepath) < 5 then Filepath := 'c:\temp\';
 
    Filepath := Filepath + Filename; 

    Report.SaveToFile(Filepath);

    Document := Client.OpenDocument('Text',Filepath);
    if bDisplay and (Document <> Nil) Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
End;

{..............................................................................}
Procedure LoadPinCountParameter;
Const
    SymbolPinCount = 'SymbolPinCount';   //parameter name.

Var
    CurrentLib      : ISch_Lib;
    LibIterator     : ISch_Iterator;
    Iterator        : ISch_Iterator;
    Units           : TUnits;
    UnitsSys        : TUnitSystem;
    AnIndex         : Integer;
    i               : integer;
    LibComp         : ISch_Component;
    Item            : ISch_Line;
    OldItem         : ISch_Line;
    Pin             : ISch_Pin;
    ReportInfo      : TStringList;
    CompName        : TString;
    CompDesg        : WideString;
    PinCount        : Integer;

    PartCount       : Integer;    // sub parts (multi-gate) of 1 component
    DMCount         : integer;
    PrevPID         : Integer;
    ThisPID         : Integer;
    ThisDMode       : TDisplayMode;

    LocX, LocY      : TCoord;
    PDes            : WideString;
    PName           : WideString;
    PLength         : TCoord;

Begin
    If SchServer = Nil Then Exit;
    CurrentLib := SchServer.GetCurrentSchDocument;
    If CurrentLib = Nil Then Exit;

    If (CurrentLib.ObjectID <> eSchLib) and (CurrentLib.ObjectID <> eSheet) Then
    Begin
         ShowError('Please open a schematic doc or library.');
         Exit;
    End;

    Units    := GetCurrentDocumentUnit;
    UnitsSys := GetCurrentDocumentUnitSystem;
    ReportInfo := TStringList.Create;

    if CurrentLib.ObjectID = eSchLib Then
        LibIterator := CurrentLib.SchLibIterator_Create
    else
        LibIterator := CurrentLib.SchIterator_Create;

    LibIterator.AddFilter_ObjectSet(MkSet(eSchComponent));

        // find the aliases for the current library component.
    LibComp := LibIterator.FirstSchObject;
    While LibComp <> Nil Do
    Begin
        CompName := LibComp.LibReference;
        CompDesg := LibComp.Designator.Text;
//        if CurrentLib.ObjectID = eSheet then
//            CompDesg := LibComp.FullPartDesignator(LibComp.CurrentPartID);

        ReportInfo.Add('Comp Name: ' + CompName + '   | Des : ' + CompDesg);
        PartCount := LibComp.PartCount;

        LibComp.GetState_PartCountNoPart0;

        ThisPID   := LibComp.CurrentPartID;
        ThisDMode := LibComp.DisplayMode;
        DMCount   := LibComp.DisplayModeCount;
        ReportInfo.Add('Number parts : ' + IntToStr(PartCount) + ' |  CurrentPartID : ' + IntToStr(ThisPID) + ' |  modes cruft : ' + IntToStr(DMCount)  + ' |  Current Mode : ' + IntToStr(ThisDMode));

        LibComp.IsMultiPartComponent;

        Iterator := LibComp.SchIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(ePin));

// Part0 is some global power pin graphic nonsense
        for i := 1 to (PartCount) do
        begin
            ReportInfo.Add('PartID : ' + IntToStr(i) + '  ' + LibComp.FullPartDesignator(i) );
            ReportInfo.Add('Pin Name  Mode     X        Y         length ');

            PinCount := 0;

            Item := Iterator.FirstSchObject;
            while Item <> Nil Do
            begin
                ThisDMode :=Item.OwnerPartDisplayMode;
                ThisPID := Item.OwnerPartId;

                if i = ThisPID then
                begin

                    If Item.ObjectID = ePin Then
                    Begin
                        Pin := Item;
                        PDes    := Pin.Designator;
                        PName   := Pin.Name;
                        PLength := Pin.PinLength;
                        LocX    := Pin.Location.X;
                        LocY    := Pin.Location.Y;
// CoordUnitToStringNoUnit(L1.x, Units)

                        ReportInfo.Add(PadRight(PDes,4) + PadRight(PName,6) + PadRight(IntToStr(ThisDMode),2) + '   ' + CoordUnitToStringWithAccuracy(LocX, Units, 5, 10) + '   '  + CoordUnitToStringwithAccuracy(LocY, Units, 5, 10)  + '  '+ CoordUnitToStringWithAccuracy(PLength, Units, 5, 10));
                        Inc(PinCount);
                    end;
                End;
                Item := Iterator.NextSchObject;

            end;
            ReportInfo.Add(' Pin Count : ' + IntToStr(PinCount));
        end;

        LibComp.SchIterator_Destroy(Iterator);
        ReportInfo.Add('');
        LibComp := LibIterator.NextSchObject;
    End;

 
    If CurrentLib.ObjectID = eSchLib Then
        // CurrentLib.SchLibIterator_Destroy(Iterator)
        CurrentLib.SchIterator_Destroy(Iterator)
    Else
        CurrentLib.SchIterator_Destroy(Iterator);

    CurrentLib.GraphicallyInvalidate;
    CurrentLib.OwnerDocument.UpdateDisplayForCurrentSheet;


    ReportInfo.Insert(0,'SchLib Part Pin Count Report');
    ReportInfo.Insert(1,'------------------------------');
    ReportInfo.Insert(2, CurrentLib.DocumentName);
    GenerateReport(ReportInfo, 'SchLibPartPinCountReport.txt');

    ReportInfo.Free;
End;

{..............................................................................}
End.

