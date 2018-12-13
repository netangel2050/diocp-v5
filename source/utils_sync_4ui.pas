unit utils_sync_4ui;

interface

uses
  Classes, SysUtils
{$IFDEF MSWINDOWS}
  , windows, messages
{$ENDIF};


const
  WM_SYNC_MSG = WM_USER + 1;

type
  TDataProc = procedure(pvData:Pointer);
  TDataEvent = procedure(pvData:Pointer) of object;
  
  TSyncTaskObject = class(TObject)
  private
    FCb:TDataEvent;
    FData:Pointer;
    FDataFreeProc:TDataProc;
  public
    procedure DoCallBack();
    procedure DoTaskForSync;
  end;




  TSync4UI = class(TObject)
  private

  protected
  {$IFDEF MSWINDOWS}
    FMessageHandle: HWND;
    procedure DoMainThreadWork(var AMsg: TMessage);
  {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    procedure RaiseMessage(const pvMsg:string);
    procedure Post(pvCb:TDataEvent; pvData:Pointer; pvDataFreeProc:TDataProc);
  end;

implementation

constructor TSync4UI.Create;
begin
  inherited Create;
  {$IFDEF MSWINDOWS}
  FMessageHandle := AllocateHWnd(DoMainThreadWork);
  {$ENDIF}
end;

destructor TSync4UI.Destroy;
begin
  {$IFDEF MSWINDOWS}
  DeallocateHWnd(FMessageHandle);
  {$ENDIF}
  inherited;
end;

{$IFDEF MSWINDOWS}

function IsClass(Obj: TObject; Cls: TClass): Boolean;
var
  Parent: TClass;
begin
  Parent := Obj.ClassType;
  while (Parent <> nil) and (Parent.ClassName <> Cls.ClassName) do
    Parent := Parent.ClassParent;
  Result := Parent <> nil;
end;


procedure HandleException();
begin
  if GetCapture <> 0 then SendMessage(GetCapture, WM_CANCELMODE, 0, 0);
  if IsClass(ExceptObject, Exception) then
  begin
    if not IsClass(ExceptObject, EAbort) then
      SysUtils.ShowException(ExceptObject, ExceptAddr);
  end else
    SysUtils.ShowException(ExceptObject, ExceptAddr);
end;

procedure TSync4UI.DoMainThreadWork(var AMsg: TMessage);
var
  lvSyncObj:TSyncTaskObject;
begin
  if AMsg.Msg = WM_SYNC_MSG then
  begin
    try
      try
        lvSyncObj := TSyncTaskObject(AMsg.WPARAM);
        lvSyncObj.DoCallBack;
      finally
        lvSyncObj.Free;
      end;
    except
      HandleException();
    end
  end else
    AMsg.Result := DefWindowProc(FMessageHandle, AMsg.Msg, AMsg.WPARAM, AMsg.LPARAM);
end;
{$ENDIF}


procedure TSync4UI.Post(pvCb:TDataEvent; pvData:Pointer;
    pvDataFreeProc:TDataProc);
var
  lvTaskData:TSyncTaskObject;
begin
  lvTaskData := TSyncTaskObject.Create;
  lvTaskData.FCb := pvCb;
  lvTaskData.FData := pvData;
  lvTaskData.FDataFreeProc := pvDataFreeProc;

  {$IFDEF MSWINDOWS}
  PostMessage(FMessageHandle, WM_SYNC_MSG, WPARAM(lvTaskData), 0)
  {$ELSE}
  TThread.Queue(nil, lvTaskData.DoTaskForSync);
  {$ENDIF}
end;

procedure TSync4UI.RaiseMessage(const pvMsg: string);
begin
  ;
end;

{ TSyncTaskObject }

procedure TSyncTaskObject.DoCallBack;
begin
  try
    FCb(self.FData);
  finally
    if Assigned(FDataFreeProc) then
    begin
      FDataFreeProc(self.FData);
    end;
  end;
end;

procedure TSyncTaskObject.DoTaskForSync;
begin
  try
    Self.DoCallBack;
  finally
    Self.Free;
  end;
end;

end.
