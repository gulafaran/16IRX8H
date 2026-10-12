/*
 * Lenovo 82WQ (BIOS KWCN51WW): \_SB.IETM._OSC writes \_TZ.ETMD, which the
 * firmware never defines (leftover from Intel's reference thermal zone code).
 * The write aborts _OSC before it updates APSV/ACRT and returns, so the
 * int3400 capability handshake from thermald fails. Define it with the
 * reference default.
 */
DefinitionBlock ("", "SSDT", 2, "TOM", "ETMDFIX", 0x00000001)
{
    Scope (\_TZ)
    {
        Name (ETMD, One)
    }
}
