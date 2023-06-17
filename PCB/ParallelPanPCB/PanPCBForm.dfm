object PanPCBForm: TPanPCBForm
  Left = 0
  Top = 0
  Hint = 'v0.27'
  Caption = 'Parallel Pan PCBs'
  ClientHeight = 213
  ClientWidth = 299
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = False
  OnClose = PanPCBFormClose
  OnMouseEnter = PanPCBFormMouseEnter
  OnMouseLeave = PanPCBFormMouseLeave
  OnShow = PanPCBFormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ebCurrentPcbDoc: TEdit
    Left = 16
    Top = 16
    Width = 272
    Height = 21
    Hint = 'Current PcbDoc'
    TabOrder = 1
    Text = 'Focused PcbDoc/PcbLib'
  end
  object editboxSelectRow: TEdit
    Left = 16
    Top = 168
    Width = 200
    Height = 21
    Hint = 'Enter or Clipboard'
    TabOrder = 0
    Text = 'Cursor Location (X, Y)'
  end
  object cbOriginMode: TComboBox
    Left = 19
    Top = 142
    Width = 145
    Height = 21
    TabOrder = 2
    Text = 'Origin Modes'
    OnChange = cbOriginModeChange
  end
  object sbStatusBar1: TStatusBar
    Left = 0
    Top = 194
    Width = 299
    Height = 19
    Panels = <>
  end
  object ebFootprintName: TEdit
    Left = 16
    Top = 41
    Width = 272
    Height = 21
    TabOrder = 4
    Text = 'Selected/Focused Footprint'
  end
  object ebLibraryName: TEdit
    Left = 16
    Top = 65
    Width = 272
    Height = 21
    TabOrder = 5
    Text = 'ComponentRef / FootprintSource Libs'
  end
  object cbStrictLibrary: TCheckBox
    Left = 21
    Top = 90
    Width = 147
    Height = 17
    Caption = 'Strict Library Name Match'
    TabOrder = 6
  end
  object cbOpenLibrary: TCheckBox
    Left = 213
    Top = 90
    Width = 75
    Height = 17
    Caption = 'Allow Open'
    TabOrder = 7
  end
  object cbAnyLibPath: TCheckBox
    Left = 213
    Top = 114
    Width = 75
    Height = 17
    Caption = 'Any Path'
    TabOrder = 8
    OnClick = cbAnyLibPathClick
  end
  object XPDirectoryEdit1: TXPDirectoryEdit
    Left = 21
    Top = 112
    Width = 179
    Height = 21
    Options = [sdNewUI, sdShowFiles]
    StretchButtonImage = False
    TabOrder = 9
    Text = 'Search FolderPath'
    OnChange = XPDirectoryEdit1Change
  end
  object Timer1: TTimer
    OnTimer = Timer1Timer
    Left = 248
    Top = 160
  end
end
