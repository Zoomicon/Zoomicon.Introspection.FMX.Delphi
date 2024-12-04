program StructureViewer_Demo;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMainForm in 'uMainForm.pas' {MainForm},
  uHidableFrame in 'uHidableFrame.pas' {HidableFrame: TFrame};

{$R *.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
