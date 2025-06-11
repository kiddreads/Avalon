using Ryujinx.Common.Utilities;
using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace Ryujinx.Graphics.Texture.Astc
{
    public struct BitStream128
    {
        private Buffer16 _data;
        public int BitsLeft { get; set; }

        public BitStream128(Buffer16 data)
        {
            _data = data;
            BitsLeft = 128;
        }

        public int ReadBits(int bitCount)
        {
            Debug.Assert(bitCount < 32);

            if (bitCount == 0)
            {
                return 0;
            }

            int mask = (1 << bitCount) - 1;
            int value = Unsafe.As<Buffer16, int>(ref _data) & mask;

            ulong carry = _data.High << (64 - bitCount);
            _data.Low = (_data.Low >> bitCount) | carry;
            _data.High >>= bitCount;

            BitsLeft -= bitCount;

            return value;
        }

        public void WriteBits(int value, int bitCount)
        {
            Debug.Assert(bitCount < 32);

            if (bitCount == 0)
            {
                return;
            }

            ulong maskedValue = (uint)(value & ((1 << bitCount) - 1));

            if (BitsLeft < 64)
            {
                ulong lowMask = maskedValue << BitsLeft;
                _data.Low |= lowMask;
            }

            if (BitsLeft + bitCount > 64)
            {
                if (BitsLeft > 64)
                {
                    _data.High |= maskedValue << (BitsLeft - 64);
                }
                else
                {
                    _data.High |= maskedValue >> (64 - BitsLeft);
                }
            }

            BitsLeft += bitCount;
        }
    }
}
