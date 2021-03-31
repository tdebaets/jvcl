unit JVCLReg;

interface

procedure Register;

implementation

uses
  Classes,
  Controls,
  JvHidControllerClass,
  JvHidControllerClassEx;

procedure Register;
begin
  RegisterComponents('System', [TJvHidDeviceController, TJvHidDeviceControllerEx]);
end;

end.
