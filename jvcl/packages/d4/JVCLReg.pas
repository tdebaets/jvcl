{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JVCLReg.pas, released on 2021-03-23.

The Initial Developer of the Original Code is Tim De Baets
Portions created by Tim De Baets are Copyright (C) 2021-2023 Tim De Baets.
All Rights Reserved.

Contributor(s): -

You may retrieve the latest version of this file at the Project JEDI's JVCL fork
located at https://github.com/tdebaets/jvcl

Known Issues:
-----------------------------------------------------------------------------}

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
