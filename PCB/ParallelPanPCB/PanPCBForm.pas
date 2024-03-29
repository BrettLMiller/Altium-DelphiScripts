{ PanPCBForm.pas
 part of PanPCB.PrjScr
 linked with PanPCBForm.dfm
 20240309   0.32 (form 0.27)

object sbStatusBar : TStatusBar
sbStatusBar.Panels.Items(0).Text := IntToStr(Key);
}
Interface    // this is ignored in delphiscript.
type
    TPanPCBForm = class(TForm)
    editboxSelectRow     : TEdit;
    ebCurrentPcbDoc      : TEdit;
    cbOriginMode         : TComboBox;
    ebFootprintName      : TTextBox;
    ebLibraryName        : TTextBox;
    sbStatusBar1         : TStatusBar;
end;

const
    fMouseOverForm   = 0;
    fMouseOverTarget = 1;
    fTimerRunning    = 3;
var
    fState           : integer;
    sbStatusBar1     : TStatusBar;
    ebFootprintName  : TEdit;
    ebLibraryName    : TEdit;
    cbStrictLibrary  : TCheckBox;
    cbOpenLibrary    : TCheckBox;
    cbAnyLibPath     : TCheckBox;
    XPDirectoryEdit1 : TXPDirectoryEdit;


function ShowForm(dummy : integer) : boolean;
begin
    PanPCBForm.FormStyle := fsStayOnTop;
    PanPCBForm.Show;
end;

procedure TPanPCBForm.PanPCBFormShow(Sender: TObject);
begin
    PanPCBForm.cbOriginMode.Items.AddStrings(slBoardRef);
    fState := fMouseOverForm;
    PanPCBForm.Timer1.Enabled              := false;
    PanPCBForm.cbStrictLibrary.Checked     := bExactLibName;
    PanPCBForm.cbOpenLibrary.Checked       := bOpenLibs;
    PanPCBForm.cbAnyLibPath.Checked        := bAnyLibPath;
    PanPCBForm.XPDirectoryEdit1.InitialDir := SearchPath;
end;

procedure TPanPCBForm.PanPCBFormClose(Sender: TObject; var Action: TCloseAction);
begin
    PanPCBForm.Timer1.Enabled := false;
    CleanExit(1);
end;

procedure TPanPCBForm.Timer1Timer(Sender: TObject);
var
    VC       : TCoordPoint;
    TBoxText : WideString;
begin
    VC := nil;
    TBoxText := 'no file';
    bExactLibName := PanPCBForm.cbStrictLibrary.Checked;
    bOpenLibs     := PanPCBForm.cbOpenLibrary.Checked;
    bAnyLibPath   := PanPCBForm.cbAnyLibPath.Checked;

    Client.BeginDisableInterface;

    RefreshFocus(1);
//    VC := FormGetCursorView(TBoxText);
    VC := CurrentCPoint;
    TBoxText := CurrentFName;

    PanPCBForm.ebCurrentPcbDoc.Text := TBoxText;
    PanPCBForm.ebFootprintName.Text := GetCurrentFPName(1);
    PanPCBForm.ebLibraryName.Text   := GetCurrentFPLibraryName(1);
    if VC <> nil then
    begin
        TBoxText := 'X' + CoordUnitToString(VC.X, eMM) + '  Y ' + CoordUnitToString(VC.Y, eMM);
        PanPCBForm.editboxSelectRow.Text  := TBoxText;
    end;

    PanProcessAll(1);
    Client.EndDisableInterface;
end;

procedure TPanPCBForm.cbOriginModeChange(Sender: TObject);
begin
    iBoardRef := cbOriginMode.ItemIndex;
    bViewPChange := true;
end;

procedure TPanPCBForm.editboxCurrentPcbDocClick(Sender: TObject);
begin
end;

procedure TPanPCBForm.PanPCBFormMouseLeave(Sender: TObject);
begin
    cbOriginMode.ItemIndex           := iBoardRef;
    PanPCBForm.XPDirectoryEdit1.Text := SearchPath;
    PanPCBForm.Timer1.Enabled        := true;
    fState := fTimerRunning;
end;

procedure TPanPCBForm.PanPCBFormMouseEnter(Sender: TObject);
begin
    PanPCBForm.Timer1.Enabled := false;
    fState := fMouseOverForm;
end;

procedure TPanPCBForm.cbAnyLibPathClick(Sender: TObject);
begin
// immediate refresh of any other Doc with matching CMP names
    if not PanPCBForm.cbAnyLibPath.Checked then bCMPChange := true;
    if not PanPCBForm.cbAnyLibPath.Checked then exit;
    SearchPath := PanPCBForm.XPDirectoryEdit1.Text;
end;

procedure TPanPCBForm.cbStrictLibraryClick(Sender: TObject);
begin
// immediate refresh of any other Doc with matching CMP names
    if not PanPCBForm.cbStrictLibrary.Checked then bCMPChange := true;;
    SearchPath := PanPCBForm.XPDirectoryEdit1.Text;
end;

procedure TPanPCBForm.cbAllowOpenClick(Sender: TObject);
begin
// immediate refresh of any other Doc with matching CMP names
    if PanPCBForm.cbAllowOpen.Checked then bCMPChange := true;;
    SearchPath := PanPCBForm.XPDirectoryEdit1.Text;
end;

procedure TPanPCBForm.XPDirectoryEdit1Change(Sender: TObject);
begin
    SearchPath := PanPCBForm.XPDirectoryEdit1.Text;
end;

