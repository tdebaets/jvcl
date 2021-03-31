unit JvHidControllerClassEx;

interface

uses Windows, SysUtils, JvHidControllerClass, Hid, JvSetupApi;

// TODO: remove
const
  SPDRP_BASE_CONTAINERID            = $00000024;  // Base ContainerID (R)

type
  TDataIndexType = (ditNone, ditButton, ditValue);

type
  TJvHidButtonEvent = procedure(HidDev: TJvHidDevice; Index: Word;
      IsOn: Boolean) of object;
  TJvHidValueEvent = procedure(HidDev: TJvHidDevice; Index: Word;
      RawValue: ULONG) of object;

type
  TJvHidPnPInfoEx = class(TJvHidPnPInfo)
  private
    fContainerId: String;
    function GetRegistryPropertyStringW(PnPHandle: HDEVINFO;
        const DevData: TSPDevInfoData; Prop: DWORD): WideString;
  public
    constructor Create(APnPHandle: HDEVINFO; ADevData: TSPDevInfoData;
        const ADevicePath: String); override;
    property ContainerId: String read fContainerId;
  end;

type
  TJvHidDeviceReadThreadEx = class(TJvHidDeviceReadThread)
  protected
    procedure DoData; override;
  end;

type
  TJvHidDeviceEx = class(TJvHidDevice)
  private
    fDataIndexTypes: array of TDataIndexType;
    fHidData: array of THIDPData;
    procedure DoButton(Index: Word; IsOn: Boolean);
    procedure DoValue(Index: Word; RawValue: ULONG);
  protected
    constructor CtlCreate(const APnPInfo: TJvHidPnPInfo;
        const Controller: TJvHidDeviceController); override;
  public
    function CheckOut: Boolean; override;
  end;

type
  TJvHidDeviceControllerEx = class(TJvHidDeviceController)
  private
    fOnDeviceButton: TJvHidButtonEvent;
    fOnDeviceValue: TJvHidValueEvent;
  protected
    function GetDeviceClass: TJvHidDeviceClass; override;
    function GetDeviceReadThreadClass: TJvHidDeviceReadThreadClass; override;
    function GetPnPInfoClass: TJvHidPnPInfoClass; override;
  published
    property OnDeviceButton: TJvHidButtonEvent
        read fOnDeviceButton write fOnDeviceButton;
    property OnDeviceValue: TJvHidValueEvent
        read fOnDeviceValue write fOnDeviceValue;
  end;

implementation

constructor TJvHidPnPInfoEx.Create(APnPHandle: HDEVINFO; ADevData: TSPDevInfoData;
    const ADevicePath: String);
begin
  inherited;
  fContainerId := GetRegistryPropertyStringW(APnPHandle, ADevData, SPDRP_BASE_CONTAINERID);
end;

function TJvHidPnPInfoEx.GetRegistryPropertyStringW(PnPHandle: HDEVINFO;
    const DevData: TSPDevInfoData; Prop: DWORD): WideString;
var
  BytesReturned: DWORD;
  RegDataType: DWORD;
  Buffer: PWideChar;
  StackBuffer: array[0..1023] of WideChar;
begin
  BytesReturned := 0;
  RegDataType := 0;
  Result := '';
  SetupDiGetDeviceRegistryProperty(PnPHandle, DevData, Prop, RegDataType, nil, 0, BytesReturned);
  if BytesReturned > 0 then
  begin
    if BytesReturned + SizeOf(WideChar) <= SizeOf(StackBuffer) then
    begin
      Buffer := @StackBuffer;
      // enforce terminator
      Buffer[BytesReturned div SizeOf(WideChar)] := #0;
    end
    else
      Buffer := AllocMem(BytesReturned + 1);

    try
      Buffer[0] := #0;
      SetupDiGetDeviceRegistryProperty(PnPHandle, DevData, Prop, RegDataType, PByte(@Buffer[0]),
        BytesReturned, BytesReturned);
      Result := Buffer;
    finally
      if Buffer <> @StackBuffer then
        FreeMem(Buffer);
    end;
  end;
end;

procedure TJvHidDeviceReadThreadEx.DoData;
var
  DeviceEx: TJvHidDeviceEx;
  i: Integer;
  DataLen: Cardinal;
  pData: PBYTE;
  Status: NTSTATUS;
begin
  inherited;
  DeviceEx := Device as TJvHidDeviceEx;
  if Length(DeviceEx.fHidData) > 0 then begin
    DataLen := Length(DeviceEx.fHidData);
    pData := @Report[0];
    Status := DeviceEx.GetData(@DeviceEx.fHidData[0], DataLen, pData^,
        NumBytesRead);
    HidCheck(Status); // TODO
    for i := 0 to DataLen - 1 do begin
      with DeviceEx.fHidData[i] do begin
        if (DataIndex >= Length(DeviceEx.fDataIndexTypes))
            or (DeviceEx.fDataIndexTypes[DataIndex] = ditButton) then
          DeviceEx.DoButton(DataIndex, On_)
        else if DeviceEx.fDataIndexTypes[DataIndex] = ditValue then
          DeviceEx.DoValue(DataIndex, RawValue);
      end;
    end;
  end;
end;

// TODO: remove?
constructor TJvHidDeviceEx.CtlCreate(const APnPInfo: TJvHidPnPInfo;
    const Controller: TJvHidDeviceController);
begin
  inherited CtlCreate(APnpInfo, Controller);
end;

procedure TJvHidDeviceEx.DoButton(Index: Word; IsOn: Boolean);
begin
  with Controller as TJvHidDeviceControllerEx do begin
    if Assigned(fOnDeviceButton) then
      fOnDeviceButton(Self, Index, IsOn);
  end;
end;

procedure TJvHidDeviceEx.DoValue(Index: Word; RawValue: ULONG);
begin
  with Controller as TJvHidDeviceControllerEx do begin
    if Assigned(fOnDeviceValue) then
      fOnDeviceValue(Self, Index, RawValue);
  end;
end;

function TJvHidDeviceEx.CheckOut: Boolean;
var
  ButtonCaps: array of THIDPButtonCaps;
  ValueCaps: array of THIDPValueCaps;
  Count: Word;
  i, RangeIdx: Integer;
  Status: NTSTATUS;
begin
  Result := inherited Checkout;
  // TODO: try to move the following to before the checkout
  ReportTypeParam := HidP_Input; // TODO: remove (requires JvHidControllerClass changes)
  SetLength(fHidData, MaxDataListLength);
  SetLength(fDataIndexTypes, Caps.NumberInputDataIndices);
  if Caps.NumberInputButtonCaps > 0 then begin
    SetLength(ButtonCaps, Caps.NumberInputButtonCaps);
    Count := Length(ButtonCaps);
    Status := GetButtonCaps(@ButtonCaps[0], Count);
    if Status = HIDP_STATUS_SUCCESS then begin
      for i := 0 to Count - 1 do begin
        with ButtonCaps[i] do begin
          if IsRange then begin
            for RangeIdx := DataIndexMin to DataIndexMax do
              fDataIndexTypes[RangeIdx] := ditButton;
          end
          else
            fDataIndexTypes[DataIndex] := ditButton;
        end;
      end;
    end;
  end;
  if Caps.NumberInputValueCaps > 0 then begin
    SetLength(ValueCaps, Caps.NumberInputValueCaps);
    Count := Length(ValueCaps);
    Status := GetValueCaps(@ValueCaps[0], Count);
    if Status = HIDP_STATUS_SUCCESS then begin // TODO: add helper function
      for i := 0 to Count - 1 do begin
        with ValueCaps[i] do begin
          if IsRange then begin
            for RangeIdx := DataIndexMin to DataIndexMax do
              fDataIndexTypes[RangeIdx] := ditValue;
          end
          else
            fDataIndexTypes[DataIndex] := ditValue;
        end;
      end;
    end;
  end;
end;

function TJvHidDeviceControllerEx.GetDeviceClass: TJvHidDeviceClass;
begin
  Result := TJvHidDeviceEx;
end;

function TJvHidDeviceControllerEx.GetDeviceReadThreadClass: TJvHidDeviceReadThreadClass;
begin
  Result := TJvHidDeviceReadThreadEx;
end;

function TJvHidDeviceControllerEx.GetPnPInfoClass: TJvHidPnPInfoClass;
begin
  Result := TJvHidPnPInfoEx;
end;

end.
