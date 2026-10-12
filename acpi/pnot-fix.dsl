/*
 * Lenovo 82WQ (BIOS KWCN51WW): EC0._Q1D/_Q37/_Q38 call PNOT, which the
 * firmware never defines. Lenovo's CPU notify helper is \SPNT (SSDT16),
 * so provide \_SB.PC00.LPCB.PNOT as a thin wrapper around it.
 */
DefinitionBlock ("", "SSDT", 2, "TOM", "PNOTFIX", 0x00000001)
{
    External (\_SB.PC00.LPCB, DeviceObj)
    External (\SPNT, MethodObj)

    Scope (\_SB.PC00.LPCB)
    {
        Method (PNOT, 0, Serialized)
        {
            If (CondRefOf (\SPNT))
            {
                \SPNT ()
            }
        }
    }
}
