namespace Ryujinx.HLE.HOS.Services.Hid.HidServer
{
    class IActiveApplicationDeviceList : IpcService
    {
        public IActiveApplicationDeviceList() { }

        [CommandCmif(0)]
        // ActivateVibrationDevice(nn::hid::VibrationDeviceHandle)
        public ResultCode ActivateVibrationDevice(ServiceCtx context)
        {
            _ = context.RequestData.ReadInt32(); // vibrationDeviceHandle

            return ResultCode.Success;
        }
    }
}
