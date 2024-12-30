unit Zoomicon.Introspection.FMX.Debugging;

interface
  uses
    System.Classes, //for TComponent
    System.Diagnostics, //for TStopWatch
    System.SysUtils; //for Exception, FreeAndNil, Format

  procedure CheckSafeMode; //must call before Application.Initialize

  procedure InitObjectDebugger(const AOwner: TComponent);
  procedure FreeObjectDebugger;
  procedure ToggleObjectDebuggerVisibility;

  procedure Log(const Format: String; const Args: array of const); overload;
  procedure Log(const Msg: String); overload;
  procedure Log(const E: Exception); overload;

  function StartTiming: TStopWatch;
  procedure StopTiming;
  function StopTiming_msec: Int64;
  function StopTiming_Ticks: Int64;

implementation
  uses
  {$IF DEFINED(MSWINDOWS)}Windows,{$ENDIF} //for GetKeyState
  //{$IF DEFINED(MACOS)}Macapi.Carbon,{$ENDIF} //Delphi doesn't have Carbon API support, need something for Cocoa
  {$IFDEF DEBUG}
    {$IF DEFINED(MSWINDOWS)}
    CodeSiteLogging,
    Zoomicon.Helpers.FMX.Forms.ApplicationHelper, //for Application.ExeName
    {$ENDIF }
  FormMessage, //for MessageForm (Object-Debugger-for-Firemonkey)
  ObjectDebuggerFMXForm, //for ObjectDebuggerFMXForm1 (Object-Debugger-for-Firemonkey)
  {$ENDIF}
  FMX.Forms, //for Application
  FMX.Skia, //for GlobalUseSkia, GlobalUseSkiaRasterWhenAvailable
  FMX.Types; //for GlobalUseDX, GlobalUseMetal, GlobalUseVulkan

resourcestring
 STR_ELAPSED_MSEC = 'Elapsed msec: %d';
 STR_ELAPSED_TICKS = 'Elapsed Ticks: %d';

{$region 'Graphics Initialization / SafeMode'}

function IsShiftKeyPressed: Boolean;
begin
  {$IF DEFINED(MSWINDOWS)}
  Result := (GetKeyState(VK_SHIFT) < 0);
  (* //Delphi doesn't have Carbon API support, need something for Cocoa
  {$ELSEIF DEFINED(MACOS)}
  var KeyMap: array[0..15] of UInt32;
  GetKeys(KeyMap); //TODO: check if working on OS-X and if deprectated //TODO: since MACOS symbol is also defined for iOS, check it doens't cause issue else use AND NOT DEFINED(IOS) above
  Result := (KeyMap[0] and (1 shl 9)) <> 0; // Check the Shift key bit
  *)
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure CheckSafeMode; //must call before Application.Initialize
begin
  if isShiftKeyPressed then //Hold down SHIFT key at app startup to disable H/W acceleration and other optimizations
  begin
    {$IF DEFINED(MSWINDOWS)}
    //GlobalUseDX10 := False; //use DX9 instead of DX10 (probably needs GlobalUseDX=true to do something)
    GlobalUseDX := False; //must do before Application.Initialize //use GDI, no h/w acceleration
    {$ENDIF}
    GlobalUseSkia := False;
    GlobalUseVulkan := False;
    GlobalUseMetal := False;
  end
  else
  begin
    GlobalUseSkia := True; //replace FMX rendering engine with Skia
    GlobalUseSkiaRasterWhenAvailable := False;
    {$IF DEFINED(MSWINDOWS) OR DEFINED(ANDROID)} //GlobalUseVulkan=true is the default on Android, checking for that for completness (for MSWindows need to combine with GlobalUseSkiaRasterWhenAvailable=False to enable if available)
    GlobalUseVulkan := True;
    {$ELSEIF DEFINED(MACOS) OR DEFINED(IOS)} //on iOS Delphi also defines MACOS symbol, but using OR for clarity (if we want to check separately need to first check for IOS and use ELSEIF to then check for MACOS)
    GlobalUseMetal := True;
    {$ENDIF}
  end;
end;

{$endregion}

{$region 'Object inspector'}

procedure InitObjectDebugger(const AOwner: TComponent);
begin
  {$IFDEF DEBUG}
  {$IF DEFINED(MSWINDOWS)} //Trying to have more than 1 form throws Segmentation Fault exception on Android, probably on iOS too. Not sure about MacOS-X or Linux, probably it works for those
  ObjectDebuggerFMXForm1 := TObjectDebuggerFMXForm.Create(AOwner); //don't Show the object inspector, MainForm shows/hides it at F11 keypress
  MessageForm := TMessageForm.Create(ObjectDebuggerFMXForm1);
  {$ENDIF}
  {$ENDIF}
end;

procedure FreeObjectDebugger;
begin
  {$IFDEF DEBUG}
  {$IF DEFINED(MSWINDOWS)} //Trying to have more than 1 form throws Segmentation Fault exception on Android, probably on iOS too. Not sure about MacOS-X or Linux, probably it works for those
  FreeAndNil(ObjectDebuggerFMXForm1); //the object debugger anyway seems to be leaking objects (if different objects are selected)
  {$ENDIF}
  {$ENDIF}
end;

procedure ToggleObjectDebuggerVisibility;
begin
  {$IFDEF DEBUG}
  if Assigned(ObjectDebuggerFMXForm1) then
    with ObjectDebuggerFMXForm1 do
      Visible := not Visible;
  {$ENDIF}
end;

{$endregion}

{$region 'Logging'}

{$IFDEF DEBUG}{$IF DEFINED(MSWINDOWS)}
procedure EnableCodeSite;
begin
  CodeSite.Enabled := CodeSite.Installed;
  if CodeSite.Enabled then
  begin
    if CodeSite.Enabled then
    begin
      var Destination := TCodeSiteDestination.Create(Application);
      with Destination do
        begin
        with LogFile do
          begin
          Active := True;
          FileName := ChangeFileExt(ExtractFileName(Application.ExeName), '.csl');
          FilePath := '$(MyDocs)\My CodeSite Files\Logs\';
          end;
        Viewer.Active := True; // also show Live Viewer
        end;
      CodeSite.Destination := Destination;
      CodeSite.Clear
    end;
  end;
end;
{$ENDIF}{$ENDIF}

procedure Log(const Format: String; const Args: array of const);
begin
  Log(System.SysUtils.Format(Format, Args));
end;

procedure Log(const Msg: String);
begin
  FMX.Types.log.d(Msg);
  {$IFDEF DEBUG}{$IF defined(MSWINDOWS)}
  try
    CodeSite.Send(Msg);
  except
    //NOP (seems CodeSite.Send(String) fails with very long strings as is the case wich serialized object trees that contain lots of TImages)
  end;
  {$ENDIF}{$ENDIF}
end;

procedure Log(const E: Exception);
begin
  {$IFDEF DEBUG}{$IF defined(MSWINDOWS)}
  try
    CodeSite.SendException(E);
  except
    //NOP (just in case it fails)
  end;
  {$ENDIF}{$ENDIF}
end;

{$endregion}

{$region 'Profiling'}

{$IFDEF DEBUG}
var profilingTimer: TStopWatch;
{$ENDIF}

function StartTiming: TStopWatch;
begin
  {$IFDEF DEBUG}
  profilingTimer.Stop;
  profilingTimer := TStopWatch.StartNew;
  {$ENDIF}
end;

procedure StopTiming;
begin
  {$IFDEF DEBUG}
  profilingTimer.Stop;
  {$ENDIF}
end;

function StopTiming_msec: Int64;
begin
  {$IFDEF DEBUG}
  StopTiming;
  result := profilingTimer.ElapsedMilliseconds;
  Log(STR_ELAPSED_MSEC, [result]);
  {$ELSE}
  result := 0;
  {$ENDIF}
end;

function StopTiming_Ticks: Int64;
begin
  {$IFDEF DEBUG}
  StopTiming;
  result := profilingTimer.ElapsedTicks;
  Log(STR_ELAPSED_TICKS, [result]);
  {$ELSE}
  result := 0;
  {$ENDIF}
end;

{$endregion}

initialization

  {$IFDEF DEBUG}
  {$IF DEFINED(MSWINDOWS)}EnableCodeSite;{$ENDIF} //TODO: is CodeSite indeed only for Windows? Couldn't compile for other platforms
  ReportMemoryLeaksOnShutdown := True;
  {$ELSE}
  //{$IF DEFINED(MSWINDOWS)}CodeSite.Enabled := False;{$ENDIF} //we've removed CodeSite with compiler defines in production version so we can't use that here
  {$ENDIF}

end.
