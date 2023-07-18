object CCForm: TCCForm
  Left = 0
  Top = 0
  Caption = 'Class Connections'
  ClientHeight = 160
  ClientWidth = 308
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnMouseEnter = CCFormMouseEnter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ComboBox1: TComboBox
    Left = 23
    Top = 17
    Width = 184
    Height = 21
    TabOrder = 0
    Text = 'cb1-NetClasses'
  end
  object Button1: TButton
    Left = 21
    Top = 90
    Width = 99
    Height = 25
    Caption = 'Show Connections'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 142
    Top = 90
    Width = 98
    Height = 25
    Caption = 'Hide Connections'
    TabOrder = 2
    OnClick = Button2Click
  end
  object ComboBox2: TComboBox
    Left = 23
    Top = 49
    Width = 184
    Height = 21
    TabOrder = 3
    Text = 'cb1-CMPClasses'
  end
  object Button3: TButton
    Left = 228
    Top = 13
    Width = 60
    Height = 25
    Caption = 'AND/OR'
    Style = bsSplitButton
    TabOrder = 4
    OnClick = Button3Click
  end
  object butShowAll: TButton
    Left = 21
    Top = 122
    Width = 99
    Height = 25
    Caption = 'Show All'
    TabOrder = 5
    OnClick = butShowAllClick
  end
  object butHideAll: TButton
    Left = 142
    Top = 122
    Width = 98
    Height = 25
    Caption = 'Hide All'
    TabOrder = 6
    OnClick = butHideAllClick
  end
  object butColour: TButton
    Left = 256
    Top = 91
    Width = 39
    Height = 25
    Caption = 'Colour'
    TabOrder = 7
    OnClick = butColourClick
  end
  object ColorDialog1: TColorDialog
    OnClose = ColorDialog1Close
    OnShow = ColorDialog1Show
    Left = 264
    Top = 120
  end
end
