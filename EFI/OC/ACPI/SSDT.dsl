/*
 * SSDT to configure GPUs:
 * - Enable Radeon RX 550 at \_SB.PC02.RP09.PXSX
 * - Disable RTX 5080 at \_SB.PC00.RP01.PXSX
 * - Added essential components for proper macOS boot
 */
DefinitionBlock ("", "SSDT", 2, "HACK", "GPUCFG", 0x00000000)
{
    // External references
    External (_SB.PC00, DeviceObj)
    External (_SB.PC00.RP01, DeviceObj)
    External (_SB.PC00.RP01.PXSX, DeviceObj)
    External (_SB.PC00.RP01.PXSX._PS3, MethodObj)
    External (_SB.PC02, DeviceObj)
    External (_SB.PC02.RP09, DeviceObj)
    External (_SB.PC02.RP09.PXSX, DeviceObj)
    External (_SB.PC02.RP09.PXSX._DSM, MethodObj)
    External (_SB.PC00.LPCB, DeviceObj)
    External (HPTE, UnknownObj)
    External (STAS, UnknownObj)

    // NVRAM/RTC Fixes
    Scope (\)
    {
        If (_OSI ("Darwin"))
        {
            HPTE = Zero
            STAS = One
        }
    }

    // Fake EC device needed for macOS
    Scope (\_SB)
    {
        Device (EC)
        {
            Name (_HID, "EC000000")  // Generic EC
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }
        }
    }

    // USBX device with power properties
    Scope (\_SB)
    {
        Device (USBX)
        {
            Name (_ADR, Zero)
            Method (_DSM, 4, NotSerialized)
            {
                If (!Arg2)
                {
                    Return (Buffer (One)
                    {
                         0x03
                    })
                }

                Return (Package (0x08)
                {
                    "kUSBSleepPowerSupply", 
                    0x13EC, 
                    "kUSBSleepPortCurrentLimit", 
                    0x0834, 
                    "kUSBWakePowerSupply", 
                    0x13EC, 
                    "kUSBWakePortCurrentLimit", 
                    0x0834
                })
            }

            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }
        }
    }

    // PMC device for power management
    Scope (\_SB.PC00)
    {
        Device (PMCR)
        {
            Name (_HID, EisaId ("APP9876"))
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0B)
                }
                Else
                {
                    Return (Zero)
                }
            }

            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite,
                    0xFE000000,         // Address Base
                    0x00010000,         // Address Length
                    )
            })
        }
    }

    // Initialize to disable the RTX 5080 during boot
    Method (_SB.PC00.RP01._INI, 0, NotSerialized)
    {
        // Call PS3 during initialization to power down
        If (CondRefOf (\_SB.PC00.RP01.PXSX._PS3))
        {
            \_SB.PC00.RP01.PXSX._PS3 ()
        }
    }

    // Scope for the RTX 5080 (to be disabled)
    Scope (\_SB.PC00.RP01.PXSX)
    {
        // Device not present
        Method (_STA, 0, NotSerialized)
        {
            Return (Zero)
        }
        
        // Device-specific method to block drivers
        Method (_DSM, 4, NotSerialized)
        {
            Return (Buffer() { 0x00 })
        }
        
        // Turning device off
        Method (_OFF, 0, NotSerialized)
        {
            If (CondRefOf (\_SB.PC00.RP01.PXSX._PS3))
            {
                \_SB.PC00.RP01.PXSX._PS3 ()
            }
        }
        
        // Return no resources for the device
        Name (_CRS, ResourceTemplate ()
        {
            Memory32Fixed (ReadWrite, 0x00000000, 0x00000000)
        })
    }
    
    // Scope for the Radeon RX 550 (to be enabled)
    Scope (\_SB.PC02.RP09.PXSX)
    {
        // Ensure device is active
        Method (_STA, 0, NotSerialized)
        {
            Return (0x0F)
        }
        
        // Add properties for GPU
        Method (_DSM, 4, NotSerialized)
        {
            If ((!Arg2))
            {
                Return (Buffer (One)
                {
                    0x03
                })
            }
            
            Return (Package ()
            {
                "AAPL,slot-name", Buffer () {"Slot-1"},
                "model", Buffer () {"Radeon RX 550"},
                "device_type", Buffer () {"Display Controller"},
                "hda-gfx", Buffer () {"onboard-1"},
                "built-in", Buffer (One) {0x01}
            })
        }
        
        // Name device as GFX0 to be proper primary GPU
        Name (_SUN, 0x00)  // Make this the primary display
    }
} 