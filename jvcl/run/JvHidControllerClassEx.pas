{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvHidControllerClassEx.pas, released on 2021-03-31.

The Initial Developer of the Original Code is Tim De Baets
Portions created by Tim De Baets are Copyright (C) 2021-2023 Tim De Baets.
All Rights Reserved.

Contributor(s): -

You may retrieve the latest version of this file at the Project JEDI's JVCL fork
located at https://github.com/tdebaets/jvcl

Known Issues:
-----------------------------------------------------------------------------}

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
  TJvHidButtonReleaseEvent = procedure(HidDev: TJvHidDevice) of object;
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
    fDataIndexTypeArr: array of TDataIndexType;
    fHidDataArr: array of THIDPData;
    procedure DoButton(Index: Word; IsOn: Boolean);
    procedure DoButtonRelease;
    procedure DoValue(Index: Word; RawValue: ULONG);
  public
    function CheckOut: Boolean; override;
  end;

type
  TJvHidDeviceControllerEx = class(TJvHidDeviceController)
  private
    fOnDeviceButton: TJvHidButtonEvent;
    fOnDeviceButtonRelease: TJvHidButtonReleaseEvent;
    fOnDeviceValue: TJvHidValueEvent;
  protected
    function GetDeviceClass: TJvHidDeviceClass; override;
    function GetDeviceReadThreadClass: TJvHidDeviceReadThreadClass; override;
    function GetPnPInfoClass: TJvHidPnPInfoClass; override;
  published
    property OnDeviceButton: TJvHidButtonEvent
        read fOnDeviceButton write fOnDeviceButton;
    property OnDeviceButtonRelease: TJvHidButtonReleaseEvent
        read fOnDeviceButtonRelease write fOnDeviceButtonRelease;
    property OnDeviceValue: TJvHidValueEvent
        read fOnDeviceValue write fOnDeviceValue;
  end;

implementation

constructor TJvHidPnPInfoEx.Create(APnPHandle: HDEVINFO; ADevData: TSPDevInfoData;
    const ADevicePath: String);
begin
  inherited;
  fContainerId := GetRegistryPropertyStringW(APnPHandle, ADevData,
      SPDRP_BASE_CONTAINERID);
end;

function TJvHidPnPInfoEx.GetRegistryPropertyStringW(PnPHandle: HDEVINFO;
    const DevData: TSPDevInfoData; Prop: DWORD): WideString;
var
  BytesReturned: DWORD;
  RegDataType: DWORD;
  pBuffer: PWideChar;
  StackBuffer: array[0..1023] of WideChar;
begin
  BytesReturned := 0;
  RegDataType := 0;
  Result := '';
  SetupDiGetDeviceRegistryProperty(PnPHandle, DevData, Prop, RegDataType, nil, 0,
      BytesReturned);
  if BytesReturned > 0 then begin
    if BytesReturned + SizeOf(WideChar) <= SizeOf(StackBuffer) then begin
      pBuffer := @StackBuffer;
      // enforce terminator
      pBuffer[BytesReturned div SizeOf(WideChar)] := #0;
    end
    else
      pBuffer := AllocMem(BytesReturned + 1);
    try
      pBuffer[0] := #0;
      SetupDiGetDeviceRegistryProperty(PnPHandle, DevData, Prop, RegDataType,
          PByte(@pBuffer[0]), BytesReturned, BytesReturned);
      Result := pBuffer;
    finally
      if pBuffer <> @StackBuffer then
        FreeMem(pBuffer);
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
  ButtonsFound: Boolean;
begin
  inherited;
  DeviceEx := Device as TJvHidDeviceEx;
  ButtonsFound := False;
  if Length(DeviceEx.fHidDataArr) > 0 then begin
    DataLen := Length(DeviceEx.fHidDataArr);
    pData := @Report[0];
    Status := DeviceEx.GetData(@DeviceEx.fHidDataArr[0], DataLen, pData^,
        NumBytesRead);
    HidCheck(Status); // TODO
    for i := 0 to DataLen - 1 do begin
      with DeviceEx.fHidDataArr[i] do begin
        if (DataIndex >= Length(DeviceEx.fDataIndexTypeArr))
            or (DeviceEx.fDataIndexTypeArr[DataIndex] = ditButton) then begin
          DeviceEx.DoButton(DataIndex, On_);
          ButtonsFound := True;
        end
        else if DeviceEx.fDataIndexTypeArr[DataIndex] = ditValue then
          DeviceEx.DoValue(DataIndex, RawValue);
      end;
    end;
    if not ButtonsFound then
      DeviceEx.DoButtonRelease;
  end;
end;

procedure TJvHidDeviceEx.DoButton(Index: Word; IsOn: Boolean);
begin
  with Controller as TJvHidDeviceControllerEx do begin
    if Assigned(fOnDeviceButton) then
      fOnDeviceButton(Self, Index, IsOn);
  end;
end;

procedure TJvHidDeviceEx.DoButtonRelease;
begin
  with Controller as TJvHidDeviceControllerEx do begin
    if Assigned(fOnDeviceButtonRelease) then
      fOnDeviceButtonRelease(Self);
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
  SetLength(fHidDataArr, MaxDataListLength);
  SetLength(fDataIndexTypeArr, Caps.NumberInputDataIndices);
  if Caps.NumberInputButtonCaps > 0 then begin
    SetLength(ButtonCaps, Caps.NumberInputButtonCaps);
    Count := Length(ButtonCaps); // needed for GetButtonCaps var parameter
    Status := GetButtonCaps(@ButtonCaps[0], Count);
    if Status = HIDP_STATUS_SUCCESS then begin // TODO: add helper function
      for i := 0 to Count - 1 do begin
        with ButtonCaps[i] do begin
          if IsRange then begin
            for RangeIdx := DataIndexMin to DataIndexMax do
              fDataIndexTypeArr[RangeIdx] := ditButton;
          end
          else
            fDataIndexTypeArr[DataIndex] := ditButton;
        end;
      end;
    end;
  end;
  if Caps.NumberInputValueCaps > 0 then begin
    SetLength(ValueCaps, Caps.NumberInputValueCaps);
    Count := Length(ValueCaps); // needed for GetValueCaps var parameter
    Status := GetValueCaps(@ValueCaps[0], Count);
    if Status = HIDP_STATUS_SUCCESS then begin // TODO: add helper function
      for i := 0 to Count - 1 do begin
        with ValueCaps[i] do begin
          if IsRange then begin
            for RangeIdx := DataIndexMin to DataIndexMax do
              fDataIndexTypeArr[RangeIdx] := ditValue;
          end
          else
            fDataIndexTypeArr[DataIndex] := ditValue;
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
