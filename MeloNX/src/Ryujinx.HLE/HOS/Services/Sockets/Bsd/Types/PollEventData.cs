namespace Ryujinx.HLE.HOS.Services.Sockets.Bsd.Types
{
    struct PollEventData
    {

        public int SocketFd;
        public PollEventTypeMask InputEvents;

        public PollEventTypeMask OutputEvents;
    }
}
