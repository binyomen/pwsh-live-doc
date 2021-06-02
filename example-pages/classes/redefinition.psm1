function GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return 'Redefinition'
}

function RunPage {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    OutputText @'
    hello
'@

    OutputCode -MinVersion 5 {
        echo '
            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }

            function GetNum {
                return [C]::GetNum()
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "Before redefinition: $(GetNum)"

        echo '
            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }

            function GetNum {
                return [C]::GetNum()
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "After redefinition: $(GetNum)"
    }

    OutputCode -MinVersion 5 {
        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }

            function GetNum {
                return [C]::GetNum()
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "Before redefinition: $(GetNum)"

        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }

            function GetNum {
                return [C]::GetNum()
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "After redefinition: $(GetNum)"
    }

    OutputCode -MinVersion 5 {
        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }
        ' > m.psm1
        $m = Import-Module -Force .\m.psm1 -PassThru
        Write-Output "Before redefinition: $(& $m {[C]::GetNum()})"

        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }
        ' > m.psm1
        $m = Import-Module -Force .\m.psm1 -PassThru
        Write-Output "After redefinition: $(& $m {[C]::GetNum()})"
    }

    OutputCode -MinVersion 5 {
        mkdir m > $null
        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }
        ' > m\m.psm1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "Before redefinition: $(& $m {[C]::GetNum()})"

        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }
        ' > m\m.psm1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "After redefinition: $(& $m {[C]::GetNum()})"
    }

    OutputCode -MinVersion 5 {
        mkdir m > $null
        echo '
            @{
                RootModule = "m.psm1"
                ModuleVersion = "0.1.0"
                GUID = "cd57dc8f-4c31-447e-862c-61dbdce81dc8"
                Author = "Test User"
                Description = "A test module"

                NestedModules = @()
            }
        ' > m\m.psd1

        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }
        ' > m\m.psm1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "Before redefinition: $(& $m {[C]::GetNum()})"

        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }
        ' > m\m.psm1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "After redefinition: $(& $m {[C]::GetNum()})"
    }

    OutputCode -MinVersion 5 {
        mkdir m > $null
        echo '
            @{
                RootModule = "m.psm1"
                ModuleVersion = "0.1.0"
                GUID = "cd57dc8f-4c31-447e-862c-61dbdce81dc8"
                Author = "Test User"
                Description = "A test module"

                NestedModules = @("m.ps1")
            }
        ' > m\m.psd1
        echo '' > m\m.psm1

        echo '
            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }
        ' > m\m.ps1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "Before redefinition: $(& $m {[C]::GetNum()})"

        echo '
            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }
        ' > m\m.ps1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "After redefinition: $(& $m {[C]::GetNum()})"
    }

    OutputCode -MinVersion 5 {
        mkdir m > $null
        echo '
            @{
                RootModule = "m.psm1"
                ModuleVersion = "0.1.0"
                GUID = "cd57dc8f-4c31-447e-862c-61dbdce81dc8"
                Author = "Test User"
                Description = "A test module"

                NestedModules = @("m.ps1")
            }
        ' > m\m.psd1
        echo '' > m\m.psm1

        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }
        ' > m\m.ps1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "Before redefinition: $(& $m {[C]::GetNum()})"

        echo '
            using namespace System.Management.Automation

            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }
        ' > m\m.ps1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "After redefinition: $(& $m {[C]::GetNum()})"
    }

    OutputCode -MinVersion 5 {
        mkdir m > $null
        echo '
            @{
                RootModule = "m.psm1"
                ModuleVersion = "0.1.0"
                GUID = "cd57dc8f-4c31-447e-862c-61dbdce81dc8"
                Author = "Test User"
                Description = "A test module"

                NestedModules = @("m.ps1")
            }
        ' > m\m.psd1
        echo '
            using namespace System.Management.Automation
        ' > m\m.psm1

        echo '
            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }
        ' > m\m.ps1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "Before redefinition: $(& $m {[C]::GetNum()})"

        echo '
            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }
        ' > m\m.ps1
        $m = Import-Module -Force .\m -PassThru
        Write-Output "After redefinition: $(& $m {[C]::GetNum()})"
    }

    OutputCode -MinVersion 5 {
        echo '
            using module .\m.psm1
            [C]::GetNum()
        ' > s.ps1

        echo '
            class C {
                static [UInt16] GetNum() {
                    return 1
                }
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "Before redefinition: $(.\s.ps1)"

        echo '
            class C {
                static [UInt16] GetNum() {
                    return 2
                }
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "After redefinition: $(.\s.ps1)"
    }

    OutputCode -MinVersion 5 {
        echo '
            Add-Type "public class C { public static int GetNum() { return 1; } }"

            function GetNum {
                return [C]::GetNum()
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "Before redefinition: $(GetNum)"

        echo '
            Add-Type "public class C { public static int GetNum() { return 2; } }"

            function GetNum {
                return [C]::GetNum()
            }
        ' > m.psm1
        Import-Module -Force .\m.psm1
        Write-Output "After redefinition: $(GetNum)"
    }
}
