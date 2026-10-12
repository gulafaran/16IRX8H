/*
 * Lenovo 82WQ (BIOS KWCN51WW): EC0._Q11/_Q12 (brightness keys) and _Q44 end
 * with Notify (WM00, 0x80), but no WM00 device exists and no WMI block on this
 * machine listens for the WEID 0xF4/0xF5 events they set up. Provide a
 * disabled stub so the Notify resolves and is dropped.
 */
DefinitionBlock ("", "SSDT", 2, "TOM", "WM00FIX", 0x00000001)
{
    Scope (\_SB)
    {
        Device (WM00)
        {
            Name (_HID, "PNP0C14" /* Windows Management Instrumentation Device */)  // _HID: Hardware ID
            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Return (Zero)
            }
        }
    }
}
