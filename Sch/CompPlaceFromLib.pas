{ CompPlaceFromLib.pas
  Place a component from IntLib or DbLib.
  Requires hardcoded comp libref & Library Name
  DBLib requires Tablename
  Only supports SchDoc.

  Works with SchLib if is part of LibPkg & focused project.

  Author: BLM
  20190511 : 1.0  first cut
  20200410 : 1.1  Added messages. Tried to fix location for DbLib placing.
  20201007   1.2  Fix the comp from DB so it places the requested part.
  20201231   1.21 Tidy code; sanitize.
  20230222   1.22 support CMP namelist file for Vault/CmpLib.
  20230824   1.30 example loading multi-part CMP from IntLib.


can work with Vault as well.
SchComp := SchServer.LoadComponent(eLibIdentifierKind_Any, 'Vault Library Name', 'Revision ID');

Export Grid uses semicolon delimiter & suffix .csv
Copy/paste uses TAB, just use .txt file.

}
const
    VaultServerName  = 'Company CP Server1';         // Vault CmpLib Server name
    CMPListFile      = 'SearchResult.txt';           // CMP "name" list .csv semi-colon delimited

Var
    FilePath    : WideSting;

Procedure PlaceCompFL();
Var
    WS           : IWorkspace;
    Prj          : IProject;
    IntLibMan    : IIntegratedLibraryManager;
    Doc          : IDocument;
    CurrentSch   : ISch_Document;

    Units        : TUnit;         // TUnit = (eMil, eMM, eIN, eCM, eDXP, eM, eAutoImperial, eAutoMetric);
    UnitsSys     : TUnitSystem;   // TUnitSystem = (eImperial, eMetric);

    CompLoc        : WideString;
    FoundLocation  : WideString;
    FoundLibName   : WideString;

    LibType        : ILibraryType;
    LibIdKind      : ILibIdentifierKind;
    LibName        : WideString;
    DBTableName    : WideString;

    SelSymbol      : WideString;
    RevisionID     : WideString;
    PCCRevID       : Widestring;

    PList          : TParameterList;
    Parameters     : TDynamicString;
    SchComp        : ISch_Component;
    SchComp2       : ISch_Component;
    SchImpl        : ISch_Implementation;
    ImpList        : TInterfaceList;
    CMPList        : TStringList;
    CMPLine        : TStringList;
    Location       : TLocation;
    sComment       : WideString;
    sDes           : WideString;
    PartCount      : integer;

    FPComp         : IPCB_LibComponent;
    FPSourceLib    : WideString;
    FPName         : WideString;

    i, j, k        : integer;

Begin
    CMPLine := TStringList.Create;
    CMPLine.Delimiter := TAB;
    CMPLine.StrictDelimiter := true;
    CMPList := TStringList.Create;
    CMPList.Delimiter := #13;
    CMPList.StrictDelimiter := true;

    FilePath := ExtractFilePath(GetCurrentDocumentFileName);
    if FileExists(FilePath + CMPListFile, false) then
    begin
        CMPList.LoadFromFile(FilePath + CMPListFile);
    end;

// Comp library reference name

// Source library name (& table)
    LibType := eLibSource;
    LibType := eLibIntegrated;      // IntLib == eLibIntegrated
//    LibType := eLibDatabase;        // DbLib == eLibDatabase
//    LibType := eLibVault;           // CmpLib== eLibVault

    DBTableName := '';

    case LibType of
    eLibSource :
      begin
        LibName     := 'Symbols.SchLib';               // Comp.SourceLibraryName
        SelSymbol   := 'RES_BlueRect_2Pin';            // junk sample.
      end;
    eLibIntegrated :   //IntLib
      begin
        LibName     := 'Resistor.IntLib';     // Comp.SourceLibraryName
        SelSymbol := '1K_0402_5%_1/16W';               // Comp.LibReference;
        SelSymbol := '0R_0402_X8_5%_1/16W';            // multi-part (x8)
      end;
    eLibDatabase :
      begin
        LibName     := 'Database_Libs1.DbLib';         // Comp.DatabaseLibraryName
        LibName     := 'Inductor.DbLib';               // Comp.DatabaseLibraryName
        DBTableName := 'Inductor';            // Comp.DatabaseTableName
        SelSymbol  := 'IND_15UH_0A78_SRR4028-150Y';
      end;
    eLibVault :
      begin
        LibName     := VaultServerName;
        RevisionID := 'CMP-006-00146-3';                // default CmpLib Revision ID
        PCCRevID   := 'PCC-010-000023-1';               // matching PCC
      end;
    end;

    WS  := GetWorkspace;
    If not Assigned(WS) Then Exit;
    Prj := WS.DM_FocusedProject;
//    If not Assigned(Prj) Then Exit;

    if PCBServer = Nil then Client.StartServer('PCB');
    if SchServer = Nil then Client.StartServer('SCH');

    Doc := WS.DM_FocusedDocument;
    If Doc.DM_DocumentKind <> cDocKind_Sch Then exit;
    If not Assigned(SchServer) Then Exit;

    CurrentSch := SchServer.GetCurrentSchDocument;
    // if you have not double clicked on Doc it may be open in project but not loaded.
    If not Assigned(CurrentSch) Then
        CurrentSch := SchServer.LoadSchDocumentByPath(Doc.DM_FullPath);
    If not Assigned(CurrentSch) Then Exit;

    Units    := GetCurrentDocumentUnit;
    UnitsSys := CurrentSch.UnitSystem;
    UnitsSys := GetCurrentDocumentUnitSystem;

    IntLibMan := IntegratedLibraryManager;
    If not Assigned(IntLibMan) Then Exit;


//  Create parameters string & list for diff methods.
    PList := TParameterList.Create;
    PList.ClearAllParameters;
    PList.SetState_FromString(Parameters);
    PList.SetState_AddParameterAsString ('Orientation', '1');               // 90 degrees
    PList.SetState_AddParameterAsString ('Location.X',  MilsToCoord(1000) );
    PList.SetState_AddParameterAsString ('Location.Y',  MilsToCoord(1000) );
    PList.SetState_AddParameterAsString ('Designator',  'DumR');
    PList.SetState_AddParameterAsString ('Comment'   ,  'dummy comment');
    PList.SetState_AddParameterAsString ('PartID'    ,  '1');

    Parameters := PList.GetState_ToString;
//    Parameters := 'Orientation=1|Location.X=10000000|Location.Y=20000000';

    FoundLocation := '';
    LibIdKind := eLibIdentifierKind_NameWithType;      // eLibIdentifierKind_Any;

 // Initialize the robots in Schematic editor.
    SchServer.ProcessControl.PreProcess(CurrentSch, '');

    case LibType of
    eLibIntegrated, eLibSource :
    begin
//        GetLibIdentifierKindFromString(LibName, cDocKind_Schlib);           // 83

//  needs full path with my IntLibs     SelSymLib not enough
       CompLoc := IntLibMan.FindComponentLibraryPath(LibIdKind, LibName, SelSymbol);
       CompLoc := IntLibMan.GetComponentLocation(LibName, SelSymbol, FoundLocation);

       if CompLoc <> '' then
       begin
// alt 1. method:
            SchComp := SchServer.LoadComponentFromLibrary(SelSymbol, CompLoc);
            PartCount := SchComp.PartCount;

            for k := 1 to SchComp.PartCount do
            begin
                SchComp.CurrentPartID := k;
                SchComp2 := SchComp.Replicate;
                SchComp2.CurrentPartID := k;
                Location := Point(MilsToCoord(1000 + (k-1)*100), MilsToCoord(1000) );
                SchComp2.MoveToXY(Location.X, Location.Y);
                SchComp2.SetState_Orientation := 0;
                SchServer.GetCurrentSchDocument.RegisterSchObjectInContainer(SchComp2);
                SchServer.RobotManager.SendMessage(CurrentSch.I_ObjectAddress,c_BroadCast, SCHM_PrimitiveRegistration,SchComp2.I_ObjectAddress);
                SchComp2.GraphicallyInvalidate;
            end;
// alt 2
//            IntLibMan.PlaceLibraryComponent(SelSymbol, FoundLocation, Parameters);
        end else
            Showmessage('Sorry, component not found in Lib ' + LibName);
    end;

    eLibDatabase :
    begin

        CompLoc := IntLibMan.GetComponentLocationFromDatabase(LibName, DBTableName,  SelSymbol, FoundLocation);
        if CompLoc <> '' then
        begin

//   warning: "Parameters" are still loaded for any server until cleared!
//   missing API fn PlaceDBLibraryComponent()
            SchComp := SchServer.LoadComponentFromDatabaseLibrary(LibName, DBTableName, SelSymbol );
            SchComp.CurrentPartID := 1;

            Location := Point(MilsToCoord(1200), MilsToCoord(1200) );
//  below does not work right as part drwn offset from location.
//            SchComp.SetState_Location := Location;
//            SchComp.Location ;

            SchComp.MoveToXY(Location.X, Location.Y);
            SchComp.SetState_Orientation := 0;                     // 0 degrees

   //         SchComp.Designator.Text := sDes;
   //         SchComp.Comment.Text := sComment;
            SchComp.SetState_xSizeySize;          // recalc bounding rect after parameter change

            SchServer.GetCurrentSchDocument.RegisterSchObjectInContainer(SchComp);
            SchServer.RobotManager.SendMessage(CurrentSch.I_ObjectAddress,c_BroadCast, SCHM_PrimitiveRegistration,SchComp.I_ObjectAddress);

            SchComp.GraphicallyInvalidate;
        end
        else
            Showmessage('Sorry, component not found in DbLib ');
    end;

    eLibVault :
    begin
        j := 0;
// if no file then add the hardcoded part.
        if CMPList.Count = 0 then
            CMPList.Add(RevisionID);

        for i := 0 to CMPList.Count - 1 do
        begin
            CMPLine.DelimitedText := CMPList.Strings(i);
// blank lines
            if trim(CMPLine.Text) =  '' then continue;

            RevisionID := CMPLine.Strings(0);

 // first row is column headings.
            if RevisionID =  'Revision ID' then continue;
            if RevisionID[0] =  '#' then continue;

            if i > 500 then continue;

            SchComp := SchServer.LoadComponent(eLibIdentifierKind_VaultName, LibName, RevisionID);
            if SchComp <> nil then
            begin
                sDes := SchComp.Designator.Text;
                sDes := ReplaceText(sDes, '?', IntToStr(i));
                SchComp.Designator.Text := sDes;

                for k := 1 to SchComp.PartCount do
                begin
                    SchComp.CurrentPartID := k;

                    Location := Point(MilsToCoord(1200 + Int(j/20) * 1000 + (k-1)*100), MilsToCoord(1200 + (j-Int(j/20)*20) * 1000 ) );
                    SchComp.MoveToXY(Location.X, Location.Y);
                    SchComp.SetState_Orientation := 0;                     // 0 degrees
                    SchComp.SetState_xSizeySize;          // recalc bounding rect after parameter change
                    SchServer.GetCurrentSchDocument.RegisterSchObjectInContainer(SchComp);
                    SchServer.RobotManager.SendMessage(CurrentSch.I_ObjectAddress,c_BroadCast, SCHM_PrimitiveRegistration,SchComp.I_ObjectAddress);
                    SchComp.GraphicallyInvalidate;
                end;
                inc(j);

                ImpList := GetState_AllImplementations(SchComp);
                for k := 0 to (ImpList.Count - 1) do
                begin
                    SchImpl := ImpList.Items(k);
                    FPSourceLib := '';
                    SchImpl.GetState_IdentifierString;
                    FPName := SchImpl.ModelName;
                    FPName := SchImpl.ModelVaultGUID;
                    FPName := SchImpl.ModelItemGUID;

                    if SchImpl.ModelType = cModelType_PCB then
                    begin
                        if SchImpl.DatafileLinkCount > 0 then
                            FPSourceLib := SchImpl.DatafileLink(0).Location;


//                    if FPSourceLib <> '' then
    // both do NOT work.
                        FPComp := PCBServer.LoadCompFromLibrary(FPName, LibName);
                        FPComp := PCBServer.LoadCompFromLibrary('PCC-010-000023-1', LibName);
                     FPComp.Name;
                    end;
                end;

            end
            else
                Showmessage('Sorry, component not found in CmpLib ');

        end;
    end;
    end; // case

    PList.Free;
    CMPLine.Free;
    CMPList.Free;

    // Clean up the robots in Schematic editor
    SchServer.ProcessControl.PostProcess(CurrentSch, '');
    SchServer.GetCurrentSchDocument.GraphicallyInvalidate;
end;

