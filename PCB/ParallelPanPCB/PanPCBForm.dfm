object PanPCBForm: TPanPCBForm
  Left = 0
  Top = 0
  Hint = 'v0.26'
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
  object btnSpareButton: TButton
    Left = 208
    Top = 152
    Width = 75
    Height = 25
    Caption = 'SpareButton'
    TabOrder = 2
  end
  object editboxSelectRow: TEdit
    Left = 16
    Top = 152
    Width = 168
    Height = 21
    Hint = 'Enter or Clipboard'
    TabOrder = 0
    Text = 'Cursor Location (X, Y)'
  end
  object cbOriginMode: TComboBox
    Left = 19
    Top = 118
    Width = 145
    Height = 21
    TabOrder = 3
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
    TabOrder = 5
    Text = 'Selected/Focused Footprint'
  end
  object ebLibraryName: TEdit
    Left = 16
    Top = 65
    Width = 272
    Height = 21
    TabOrder = 6
    Text = 'ComponentRef / FootprintSource Libs'
  end
  object cbStrictLibrary: TCheckBox
    Left = 21
    Top = 90
    Width = 147
    Height = 17
    Caption = 'Strict Library Name Match'
    TabOrder = 7
  end
  object Timer1: TTimer
    OnTimer = Timer1Timer
    Left = 24
    Top = 168
  end
end
