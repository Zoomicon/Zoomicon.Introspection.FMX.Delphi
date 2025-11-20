unit uMainForm;

interface

{$region 'Used units'}
uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  //
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.Controls.Presentation,
  FMX.MultiView,
  FMX.Layouts,
  //
  Zoomicon.Introspection.FMX.StructureView, //for TStructureView
  uHidableFrame;
{$endregion}

type
  TMainForm = class(TForm)
    MultiView: TMultiView;
    HidableFrame1: THidableFrame;
    btnMenu: TSpeedButton;
    ContentLayout: TLayout;
    btnShowChildren: TButton;
    MainLayout: TLayout;
    HidableFrame2: THidableFrame;
    HidableFrame3: THidableFrame;
    procedure btnShowChildrenClick(Sender: TObject);
    procedure MultiViewStartShowing(Sender: TObject);
  protected
    FStructureView: TStructureView;
    procedure StructureViewSelection(Sender: TObject; const Selection: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.btnShowChildrenClick(Sender: TObject);
begin
  for var Control in ContentLayout.Controls do
    Control.Visible := true;
end;

procedure TMainForm.StructureViewSelection(Sender: TObject; const Selection: TObject);
begin
  ShowMessage(TControl(Selection).ClassName);
  MultiView.HideMaster;
end;

procedure TMainForm.MultiViewStartShowing(Sender: TObject);
begin
  if not Assigned(FStructureView) then
  begin
    FStructureView:= TStructureView.Create(MultiView);
    with FStructureView do
    begin
      GUIRoot := ContentLayout;
      OnSelection := StructureViewSelection;
    end;
  end;
end;

end.
