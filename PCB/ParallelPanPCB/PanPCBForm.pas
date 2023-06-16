{ PanPCBForm.pas
 part of PanPCB.PrjScr
 linked with PanPCBForm.dfm
 20230616   0.26

object sbStatusBar : TStatusBar
sbStatusBar.Panels.Items(0).Text := IntToStr(Key);
}
Interface    // this is ignored in delphiscript.
type
    TPanPCBForm = class(TForm)
    editboxSelectRow     : TEdit;
    ebCurrentPcbDoc      : TEdit;
    cbOriginMode         : TComboBox;
    btnSpareButton       : TButton;
    ebFootprintName      : TTextBox;
    ebLibraryName        : TTextBox;
    sbStatusBar1         : TStatusBar;
end;

const
    fMouseOverForm   = 0;
    fMouseOverTarget = 1;
    fTimerRunning    = 3;
var
    fState          : integer;
    sbStatusBar1    : TStatusBar;
    ebFootprintName : TEdit;
    ebLibraryName   : TEdit;
    cbStrictLibrary : TCheckBox;

procedure TPanPCBForm.PanPCBFormShow(Sender: TObject);
begin
    PanPCBForm.cbOriginMode.Items.AddStrings(slBoardRef);
    fState := fMouseOverForm;
    PanPCBForm.Timer1.Enabled := false;
    PanPCBForm.cbStrictLibrary.Checked := bExactLibName;
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
    PanPCBForm.ebFootprintName.Text := 'no footprint selected';
    PanPCBForm.ebLibraryName.Text   := ' ';

    RefreshFocus(1);

    VC := GetCursorView(TBoxText);
    PanPCBForm.ebCurrentPcbDoc.Text := TBoxText;
    PanPCBForm.ebFootprintName.Text := GetCurrentFPName(1);
    PanPCBForm.ebLibraryName.Text   := GetCurrentFPLibraryName(1);
    if VC <> nil then
    begin
        TBoxText := 'X' + CoordUnitToString(VC.X, eMM) + '  Y ' + CoordUnitToString(VC.Y, eMM);
        PanPCBForm.editboxSelectRow.Text  := TBoxText;
    end;

    PanOtherPCBDocs(1);
    PanOtherPcbLibs(1);
end;

procedure TPanPCBForm.cbOriginModeChange(Sender: TObject);
begin
    iBoardRef := cbOriginMode.ItemIndex;
end;

procedure TPanPCBForm.editboxCurrentPcbDocClick(Sender: TObject);
begin
end;

procedure TPanPCBForm.PanPCBFormMouseLeave(Sender: TObject);
begin
    cbOriginMode.ItemIndex := iBoardRef;
    PanPCBForm.Timer1.Enabled := true;
    fState := fTimerRunning;
end;

procedure TPanPCBForm.PanPCBFormMouseEnter(Sender: TObject);
begin
    PanPCBForm.Timer1.Enabled := false;
    fState := fMouseOverForm;
end;

