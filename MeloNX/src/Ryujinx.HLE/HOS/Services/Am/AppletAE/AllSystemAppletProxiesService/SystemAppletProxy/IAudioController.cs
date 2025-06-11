using Ryujinx.Common.Logging;

namespace Ryujinx.HLE.HOS.Services.Am.AppletAE.AllSystemAppletProxiesService.SystemAppletProxy
{
    class IAudioController : IpcService
    {
        public IAudioController() { }

        [CommandCmif(0)]
        // SetExpectedMasterVolume(f32, f32)
        public ResultCode SetExpectedMasterVolume(ServiceCtx context)
        {
            _ = context.RequestData.ReadSingle(); // applet volume
            _ = context.RequestData.ReadSingle(); // library applet volume

            Logger.Stub?.PrintStub(LogClass.ServiceAm);

            return ResultCode.Success;
        }

        [CommandCmif(1)]
        // GetMainAppletExpectedMasterVolume() -> f32
        public ResultCode GetMainAppletExpectedMasterVolume(ServiceCtx context)
        {
            context.ResponseData.Write(1f);

            Logger.Stub?.PrintStub(LogClass.ServiceAm);

            return ResultCode.Success;
        }

        [CommandCmif(2)]
        // GetLibraryAppletExpectedMasterVolume() -> f32
        public ResultCode GetLibraryAppletExpectedMasterVolume(ServiceCtx context)
        {
            context.ResponseData.Write(1f);

            Logger.Stub?.PrintStub(LogClass.ServiceAm);

            return ResultCode.Success;
        }

        [CommandCmif(3)]
        // ChangeMainAppletMasterVolume(f32, u64)
        public ResultCode ChangeMainAppletMasterVolume(ServiceCtx context)
        {
            // Unknown parameters.
            _ = context.RequestData.ReadSingle();
            _ = context.RequestData.ReadInt64();

            Logger.Stub?.PrintStub(LogClass.ServiceAm);

            return ResultCode.Success;
        }

        [CommandCmif(4)]
        // SetTransparentVolumeRate(f32)
        public ResultCode SetTransparentVolumeRate(ServiceCtx context)
        {
            // Unknown parameter.
            _ = context.RequestData.ReadSingle();

            Logger.Stub?.PrintStub(LogClass.ServiceAm);

            return ResultCode.Success;
        }
    }
}
