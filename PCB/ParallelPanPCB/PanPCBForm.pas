{ PanPCBForm.pas
 part of PanPCB.PrjScr
 linked with PanPCBForm.dfm
}
Interface    // this is ignored in delphiscript.
type
    TPanPCBForm = class(TForm)
    editboxSelectRow    : TEdit;
    editboxNewRowName   : TEdit;
    btnSpareButton      : TButton;
end;

const
    fMouseOverForm = 0;
    fMouseOverTarget = 1;

var
    fState : integer;
    sEntry : WideString;

procedure TPanPCBForm.PanPCBFormShow(Sender: TObject);
begin
    fState := fMouseOverForm;
    PanPCBForm.Timer1.Enabled := false;
end;

procedure TPanPCBForm.PanPCBFormClose(Sender: TObject; var Action: TCloseAction);
begin
    PanPCBForm.Timer1.Enabled := false;
end;

procedure TPanPCBForm.Timer1Timer(Sender: TObject);
var
    VR : TcoordRect;
    VC : TcoordPoint;
begin
    VR := nil;
    If not FocusedPCB(1) then exit;

    VR := GetViewRect(1);
    if VR <> nil then
    begin
        sEntry := 'L' + CoordUnitToString(VR.X1, eMM) + '  R ' + CoordUnitToString(VR.X2, eMM);
        PanPCBForm.editboxSelectRow.Text  := sEntry;
        PanPCBForm.editboxCurrentPcbDoc.Text := CurrentPCB.FileName;
    end;
    PanOtherPCBDocs(1);
end;

procedure TPanPCBForm.editboxCurrentPcbDocClick(Sender: TObject);
begin
end;

procedure TPanPCBForm.PanPCBFormMouseLeave(Sender: TObject);
begin
      PanPCBForm.Timer1.Enabled := true;
end;

procedure TPanPCBForm.PanPCBFormMouseEnter(Sender: TObject);
begin
     PanPCBForm.Timer1.Enabled := false;
end;

