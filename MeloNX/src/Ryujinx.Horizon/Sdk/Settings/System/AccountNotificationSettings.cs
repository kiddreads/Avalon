using Ryujinx.Horizon.Sdk.Account;

namespace Ryujinx.Horizon.Sdk.Settings.System
{
    struct AccountNotificationSettings
    {

        public Uid UserId;
        public uint Flags;
        public byte FriendPresenceOverlayPermission;
        public byte FriendInvitationOverlayPermission;
        public ushort Reserved;

    }
}
